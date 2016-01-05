module Hanuman
  class Rule < ActiveRecord::Base
    belongs_to :question
    has_many :rule_conditions
    has_many :conditions, through: :rule_conditions

    MATCH_TYPES = ["any","all"]
  end
end
