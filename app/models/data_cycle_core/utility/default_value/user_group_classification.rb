# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module UserGroupClassification
        class << self
          def by_user(current_user:, key:, **_additional_args)
            return unless current_user

            ids = Array.wrap(current_user.user_groups.try(key)&.primary_classifications&.pluck(:id))

            # multiple: false declares the relation single-valued; a user inheriting several
            # values through several groups has no unambiguous default and gets none
            return if ids.many? && DataCycleCore::Feature::UserGroupClassification.attribute_relations.dig(key, 'multiple') == false

            ids
          end
        end
      end
    end
  end
end
