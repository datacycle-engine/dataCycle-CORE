# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module String
        class << self
          def substitution(content:, property_definition:, **_additional_args)#
            identifier = property_definition&.dig('default_value', 'attribute').to_s == 'slug' ? content&.slug : content&.id
            format(property_definition&.dig('default_value', 'substitute_string').to_s, id: identifier).presence
          end

          def current_user(current_user:, **_additional_args)
            user_string(current_user)
          end

          def linked_gip_route_attribute(property_parameters:, property_definition:, **_additional_args)
            return if property_parameters.values.first.blank?

            DataCycleCore::Thing.find_by(id: property_parameters.values.first)&.send(property_definition&.dig('default_value', 'linked_attribute').to_s)
          end

          def copy_from_translation(content:, key:, **_additional_args)
            I18n.with_locale(content.first_available_locale) { content.try(key) }
          end

          private

          def user_string(user)
            return if user.nil?

            "#{user.given_name} #{user.family_name} <#{user.email}>".squish
          end
        end
      end
    end
  end
end
