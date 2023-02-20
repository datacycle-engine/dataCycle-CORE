# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class SubjectByUserRolesWhitelist < Base
        attr_reader :subject, :user_attribute_name, :whitelisted_role_names

        def initialize(subject, user_attribute_name, whitelisted_role_names = [])
          @subject = subject
          @user_attribute_name = user_attribute_name
          @whitelisted_role_names = whitelisted_role_names
        end

        def conditions
          { user_attribute_name.to_sym => { role: { name: whitelisted_role_names } } }
        end
      end
    end
  end
end
