module Hanuman
  class Question < ActiveRecord::Base
    acts_as_taggable
    has_paper_trail
    has_ancestry

    attr_accessor :single_cloning, :flagged_answers_change_was_saved

    # Relations
    belongs_to :answer_type
    belongs_to :survey_template
    has_many :answer_choices, -> { order :sort_order, :option_text }, dependent: :destroy, inverse_of: :question
    # if a user deletes a question from survey admin we need to delete related observations, giving warning in survey admin
    has_many :observations, dependent: :destroy #**** controlling the delete through a confirm on the ember side of things-kdh *****
    has_many :rules, dependent: :destroy
    has_many :conditions, dependent: :destroy # The conditions this question is dependent of
    has_many :rule_conditions, through: :rules, source: :conditions

    # Validations
    validates :answer_type_id, presence: true
    # wait until after migration for these validations
    validates :question_text, presence: true, unless: :question_text_not_required

    # validates_uniqueness_of :db_column_name, scope: :survey_template_id, allow_blank: true
    validates_format_of :db_column_name, with: /\A\w+\Z/i, allow_blank: true
    # validates_uniqueness_of :api_column_name, scope: :survey_template_id, allow_blank: true
    validates_format_of :api_column_name, with: /\A\w+\Z/i, allow_blank: true
    

    # Callbacks
    after_create :process_question_changes_on_observations, if: :survey_template_not_fully_editable?
    after_create :set_column_names!
    after_update :process_question_changes_on_observations, if: :survey_template_not_fully_editable_or_sort_order_changed?
    before_update :answer_type_change, if: :answer_type_id_changed?
    after_save :format_css_style, if: :css_style_changed?

    # Need to cache the change state of flagged answers in an attribute so that we can access it after_commit
    # Need to start this worker after_commit to avoid it firing before the transaction has completed
    after_save -> { self.flagged_answers_change_was_saved = true }, if: :flagged_answers_changed?
    after_commit :schedule_flagged_answers_update_worker, if: :flagged_answers_change_was_saved

    # Scopes
    # scope :not_marked_for_deletion, -> { where(marked_for_deletion: false) }
    default_scope { where(marked_for_deletion: false) }


    amoeba do
      include_association :rules
      include_association :answer_choices
      include_association :conditions, if: :survey_cloning?

      # set duplicated_question_id so I can remap the ancestry relationships on a survey template duplicate-kdh
      customize(lambda { |original_question,new_question|
        new_question.duped_question_id = original_question.id
      })
    end

    def self.sort(sort_column, sort_direction)
      joins(:answer_type).order(("#{sort_column}  #{sort_direction}")
        .gsub('asc asc', 'asc')
        .gsub('asc desc', 'asc')
        .gsub('desc desc', 'desc')
        .gsub('desc asc', 'desc'))
    end

    def question_text_not_required
      return false if answer_type.blank?
      return answer_type.name == 'line'
    end

    # adding this method so I can check it before calling the job to process question changes on observations to try and decrease the number of 404 errors coming through
    def survey_template_not_fully_editable?
      !survey_template.try(:fully_editable)
    end

    # adding this method so I can check it before calling the job to process question changes on observations to try and decrease the number of 404 errors coming through
    def survey_template_not_fully_editable_or_sort_order_changed?
      survey_template_not_fully_editable? && sort_order_changed?
    end

    def format_css_style
      if self.css_style.present?
        self.update_column(:css_style, self.css_style.gsub("\n", ""))
      end
    end

      # need to process question changes on observation in job because the changes could cause timeout on survey template with a bunch of questions
    def process_question_changes_on_observations
      ProcessQuestionChangesWorker.perform_async(id)
    end

    # if survey has data submitted against it, then submit blank data for each
    # survey for newly added question, then re-save survey so that group_sort gets reset
    def submit_blank_observation_data
      question = self
      parent = question.parent
      survey_template = question.survey_template
      surveys = survey_template.surveys
      surveys.each do |s|
        if parent.blank?
          Observation.create_with(
            answer: ''
          ).find_or_create_by(
            survey_id: s.id,
            question_id: question.id,
            entry: 1
          )
        # if new question is in a repeater must add observation for each instance of repeater saved in previous surveys
        else
          s.observations.where(question_id: parent.id).each do |o|
            Hanuman::Observation.create_with(
              answer: ''
            ).find_or_create_by(
              survey_id: s.id,
              question_id: question.id,
              entry: o.entry,
              parent_repeater_id: o.repeater_id
            )
          end
        end

        s.update_column(:observations_sorted, false)
        s.update_column(:observation_visibility_set, false)
      end
    end

    # build the rule_hash to pass into rails to then be used by javascript for hide/show functions
    def rule_hash
      # "rule": {
      #         "id": "1",
      #         "question_id": "822",
      #         "match_type": "all",
      #         "conditions": [
      #           {
      #             "id": "1",
      #             "question_id": "818",
      #             "operator": "is equal to",
      #             "answer": "Yes"
      #           }
      #         ]
      #       }
      unless self.rules.blank?
        ActiveModel::ArraySerializer.new(self.rules, each_serializer: Hanuman::RuleHashSerializer).to_json
      end
    end

    def survey_cloning?
      !!!single_cloning
    end

    # duplicate and save a single question with answer choices and conditions
    def dup_and_save(new_parent = nil, new_sort_order = nil)
      self.single_cloning = true
      new_q = self.amoeba_dup

      if new_sort_order.present?
        new_q.sort_order = new_sort_order
      else
        new_q.sort_order = self.sort_order.to_i
      end

      if new_parent.present?
        new_q.parent = new_parent
      end

      new_q.save
      # Associate the conditions from the rule
      self.rules.each do |rule|
        rule.conditions.each do |condition|
          new_condition = condition.amoeba_dup
          new_condition.rule = new_q.rules.find_by(duped_rule_id: rule.id)
          new_condition.save
        end
      end
      new_q
    end

    def dup_section
      section_q = self
      descendants_qs = section_q.descendants.order(:sort_order)
      start_sort_order = 100000
      increment_sort_by = 2
      unless descendants_qs.blank?
        start_sort_order = descendants_qs.last.sort_order
        # number of new descendants questions + condition (parent) and descendants (rule) questions
        increment_sort_by = descendants_qs.count + 1
      else
        start_sort_order = section_q.sort_order
      end

      # remap sort orders leaving space for new questions before saving new question
      section_q.survey_template.questions.where("sort_order > ?", start_sort_order).each do |q|
        q.paper_trail.without_versioning do
          q.update_attribute('sort_order', q.sort_order + increment_sort_by)
        end
      end

      # this will duplicate the question, will need to create a new rule,
      # and then set the condtions to new rule id
      new_section_q = section_q.amoeba_dup
      new_section_q.sort_order = new_section_q.sort_order + increment_sort_by
      new_section_q.save
      descendants_qs.each do |q|
        new_child_parent = new_section_q.descendants.find_by(duped_question_id: q.parent.id) || new_section_q
        new_child_parent.save
        new_sort_order = q.sort_order + increment_sort_by
        q.dup_and_save(new_child_parent, new_sort_order)
      end

      # Re-organize / map conditions
      new_section_q.descendants.order(:sort_order).each do |question|
        next if question.rule_conditions.empty?
        question.rule_conditions.each do |condition|
          next unless descendants_qs.include?(condition.question)
          condition.question_id = new_section_q.descendants.find_by(duped_question_id: condition.question.id).id
          condition.save
        end
      end

      # Associate the conditions from the rule
      self.rules.each do |rule|
        rule.conditions.each do |condition|
          new_condition = condition.amoeba_dup
          new_condition.rule = new_section_q.rules.find_by(duped_rule_id: rule.id)
          new_condition.save
        end
      end

      new_section_q
    end

    def import_answer_choices(file_name, file_path)
      spreadsheet = Import::open_spreadsheet(file_name, file_path)
      header = spreadsheet.row(1)
      imported = []
      not_imported = []
      message = nil
      if header.index("Answer Choices").blank?
        message = "Could not import answer choices because we found no 'Answer Choices' column."
      else
        (2..spreadsheet.last_row).each do |i|
          row = Hash[[header, spreadsheet.row(i)].transpose]
          name = row["Answer Choices"]
          answer_choice = AnswerChoice.where(option_text: name, question_id: self.id)
          if answer_choice.blank?
            imported << name
            AnswerChoice.create(option_text: name, question_id: self.id)
          else
            not_imported << name
          end
        end
        puts "********"
        puts "********"
        puts "********"
        puts "imported"
        puts imported
        puts "********"
        puts "********"
        puts "********"
        puts "not imported"
        puts not_imported
        puts "********"
        puts "********"
        puts "********"
        message = "number of answer choices imported: #{imported.count.to_s}; number of answer choices not imported because they are already attached to the question: #{not_imported.count.to_s}."
      end
      message
    end


    def set_old_db_column_name
      if self.db_column_name.blank?
        shorthand = self.question_text.strip.parameterize.underscore.gsub(/\s|:|\//, '-').truncate(16, omission: "") + "_"
        counter = 0

        taken = true
        while taken do
          self.survey_template.questions.each do |q|
            begin
              raise if q.db_column_name == shorthand + counter.to_s
            rescue
              counter += 1
              retry
            end
          end
          taken = false
        end
        self.update_column(:db_column_name, shorthand + counter.to_s)
      end
    end


    def parameterized_text
      self.question_text.strip.parameterize.underscore.gsub(/\s|:|\//, '-')
    end

    def column_name
      base_string = parameterized_text
      if base_string.length > 60
        base_string = base_string[0..59]
      end
      if self.ancestry?
        base_plus_parent = base_string
        self.ancestors.order(sort_order: :desc).each do |a|
          base_plus_parent = (a.parameterized_text + "_") + base_plus_parent
          if base_plus_parent.length > 60
            break
          else 
            base_string = base_plus_parent
          end
        end
      end
      
      # checking for duplicate api_column_names and incrementing index by 1
      if Hanuman::Question.exists?(api_column_name: base_string, survey_template_id: self.survey_template_id)
        index = 1
        
        loop do
          if Hanuman::Question.exists?(api_column_name: base_string + "_#{index}", survey_template_id: self.survey_template_id)
            index += 1
          else
            return base_string + "_#{index}"
          end 
        end 
      else
        base_string
      end 
    end

    def set_column_names!
      self.db_column_name = column_name if self.db_column_name.blank?
      self.api_column_name = column_name if self.api_column_name.blank?
      save
    end 

    def set_api_column_name!
      self.api_column_name = column_name if self.api_column_name.blank?
      save
    end

    def update_css_style(style_string)
      ### method to update css style to avoid accidentally losing styling, and to make upating the style easier

      # regex to match the basic formatting of css attribute lines
      regex = %r([A-Za-z\- ]+[:][\s#]*[\w .\/()\-!%]+;)
      valid_string = style_string.scan(regex).join

      new_matches = style_string.scan(regex)
      if valid_string == style_string
        if css_style.present?
          old_matches = css_style.scan(regex)
          old_hash = {}
          new_hash = {}

          # build hashes of existing style attributes and proposed additions to avoid having dup entries
          old_matches.each do |m|
            m = m.to_s
            old_hash[m.split(':')[0]] = m.split(':')[1]
          end

          new_matches.each do |m|
            m = m.to_s
            new_hash[m.split(':')[0]] = m.split(':')[1]
          end

          # concatonate all changes to update column value
          new_style_string = ""

          # keep track of newly updated attributes
          updated = []

          new_hash.each do |k,v|
            if old_hash[k].present?
              # update attribute case
              new_style_string += "#{k.to_s}:#{new_hash[k].to_s}"
              updated << k
              puts "updating attribute #{k}:#{old_hash[k]} to #{k}:#{new_hash[k]}"
            else
              # new attribute case
              new_style_string += "#{k.to_s}:#{new_hash[k].to_s}"
              puts "new attribute #{k}:#{new_hash[k]}"
            end
          end

          old_hash.each do |k,v|
            if !updated.include?(k)
              # if not updated include old value in new style
              new_style_string += "#{k.to_s}:#{old_hash[k].to_s}"
              puts "unchanged attribute #{k}:#{old_hash[k]}"
            end
          end
          

          self.css_style = new_style_string
          self.save
        else
          self.css_style = valid_string
          self.save
          puts "newly added style"
        end
      else
        puts "does not appear to be valid css, check syntax and try again"
      end
    end

    def display_css_style
      ### better display of style to help when coding/styling

      # split at semicolon but keep delimeter
      css_style.split(/(?<=[;])/)
    end

    def mark_all_descendants_for_deletion
      if self.children.present?
        self.marked_for_deletion = true
        self.save
        self.children.each do |child|
          child.mark_all_descendants_for_deletion
        end
      else
        self.marked_for_deletion = true
        self.save
      end
    end

    def answer_type_change
      default_answer = false
      ['checkbox', 'number', 'radio', 'text', 'textarea'].each do |at|
        if self.answer_type.name == at
          default_answer = true
        end
      end
      unless default_answer
        self.default_answer = nil
      end
    end

    def flagged_answers=(value)
      if value.nil? or !value.is_a?(String)
        self[:flagged_answers] = []
      else
        self[:flagged_answers] = value.split(',').map(&:strip)
      end
    end

    def schedule_flagged_answers_update_worker
      UpdateFlaggedAnswersWorker.perform_async(id)
      self.flagged_answers_change_was_saved = false
    end

    def calculated?
      self.rules.any? { |r| r.is_a?(Hanuman::CalculationRule) }
    end
  end
end
