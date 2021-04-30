module Hanuman
  class Condition < ActiveRecord::Base
    has_paper_trail

    attr_accessor :dup_copying
    # delegate :update_observation_visibility, to: :rule

    # Constants
    OPERATORS = [
      'is equal to', 'is not equal to', 'is empty', 'is not empty',
      'is greater than', 'is less than', 'starts with', 'contains'
    ]

    # Relations
    belongs_to :question
    belongs_to :rule

    # Validations
    validates :rule_id, presence: true, unless: :dup_copying
    validates :operator, inclusion: { in: OPERATORS }
    #validates :question_id, presence: true - this validation breaks the duplicate functionality-kdh
    #validates :answer, presence: true - is empty and is not empty have nil values for answer so we can't validate presence of answer-kdh

    # Callbacks
    after_destroy :cleanup_rule_if_single_condition
    after_commit :update_observation_visibility

    amoeba do
      enable
      exclude_associations :deltas
    end

    # when a condition gets deleted, check to see of the rule attached to that condition has other conditions attached to it
    # if it does do NOT delete, if it doen NOT have any more conditions attached go ahead and delete
    def cleanup_rule_if_single_condition
      # adding this line because we have some conditions referencing a rule that no longer exists and that is making survey template delete fail
      unless rule.blank?
        if rule.conditions.blank?
          self.rule.destroy
        end
      end
    end


    def update_observation_visibility
      unless self.question.blank? || self.question.survey_template.blank?
        self.question.survey_template.surveys.where(observation_visibility_set: true).each do |s|
          s.update_column(:observation_visibility_set, false)
        end
      end
    end



  end
end
