# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class SubjectByUserAndConditions < Base
        attr_reader :subject, :additional_conditions, :user_attribute_name

        def initialize(subject, user_attribute_name, **additional_conditions)
          @subject = subject
          @user_attribute_name = user_attribute_name
          @additional_conditions = additional_conditions
        end

        def conditions
          { user_attribute_name.to_sym => user&.id }.merge(additional_conditions)
        end
      end
    end
  end
end
