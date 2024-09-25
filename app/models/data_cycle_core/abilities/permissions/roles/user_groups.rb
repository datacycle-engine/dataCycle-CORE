# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module UserGroups
          def load_permissions_for_user_groups(role = DataCycleCore::Feature::UserGroupPermission.configuration.dig('default_role')&.to_sym || :standard)
            groups_with_permissions = DataCycleCore::UserGroup.where.not(permissions: nil)

            groups_with_permissions.each do |user_group|
              next if user_group.blank? || user_group.name.blank?

              permissions = user_group.permissions.select(&:present?)
              feature_abilities = DataCycleCore::Feature::UserGroupPermission.configuration.dig('abilities').select { |k, _v| permissions.include?(k) }

              feature_abilities.each_value do |v|
                actions = Array.wrap(v[:actions]).map(&:to_sym)
                segment = v[:segment]

                collections = v[:parameters].size.positive? ? Array.wrap(v[:parameters][0]) : []
                template_names = v[:parameters].size > 1 ? Array.wrap(v[:parameters][1]) : []

                collections = collections.map { |p|
                  return Array.wrap(p) unless p == '<COLLECTION>'
                  user_group.shared_collection_ids
                }.flatten

                parameters = [collections, template_names]

                permit_user_group(user_group.name, role, *actions, {segment.to_sym => parameters})
              end
            end
          end
        end
      end
    end
  end
end
