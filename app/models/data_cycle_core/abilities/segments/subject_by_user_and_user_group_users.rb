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
      end
    end
  end
end
