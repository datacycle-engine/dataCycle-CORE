# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class SubjectByUserAndUserGroupUsers < Base
        attr_reader :subject, :user_attribute_name

        def initialize(subject, user_attribute_name)
          @subject = subject
          @user_attribute_name = user_attribute_name
        end

        def conditions
          { user_attribute_name.to_sym => user&.include_groups_user_ids }
        end

        def to_s
          I18n.t(
            "abilities.segments.#{self.class.name.demodulize.underscore}",
            locale:,
            data: translated_subjects,
            attribute_name: Array.wrap(subject).first.human_attribute_name(user_attribute_name, locale:)
          )
        end

        private

        def to_restrictions(subject:, **)
          to_restriction(attribute_name: subject.human_attribute_name(user_attribute_name, locale:)) if user_attribute_name.to_s != 'id'
        end
      end
    end
  end
end
