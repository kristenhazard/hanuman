module Hanuman
  class SurveyTemplateSerializer < ActiveModel::Serializer
    attributes :id, :name, :status, :survey_type, :fully_editable, :duplicator_label, :description, :version, :lock, :name_plus_version
    has_many :questions, embed: :ids

    def duplicator_label
      Hanuman::Setting.value("duplicator_step_label")
    end
  end
end
