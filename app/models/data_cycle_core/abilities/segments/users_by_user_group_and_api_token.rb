# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByUserGroupAndApiToken < UsersByUserGroup
        attr_accessor :group_name, :roles, :subject

        def include?(user)
          role?(user) && user_group?(user) && user.access_token.present?
        end
      end
    end
  end
end
