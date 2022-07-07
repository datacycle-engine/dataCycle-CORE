# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module UserGroupClassification
        class << self
          def by_user(current_user:, key:, **_additional_args)
            return unless current_user

            Array.wrap(current_user.user_groups.try(key)&.primary_classifications&.pluck(:id))
          end
        end
      end
    end
  end
end
