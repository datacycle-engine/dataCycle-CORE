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

        private

        def to_restrictions(subject:, **)
          restrictions = additional_conditions.map { |k, v| "#{k} => #{v}" }
          restrictions.unshift(to_restriction(attribute_name: subject.human_attribute_name(user_attribute_name, locale:))) if user_attribute_name.to_s != 'id'

          restrictions
        end
      end
    end
  end
end
