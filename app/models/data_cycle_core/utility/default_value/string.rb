# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module String
        class << self
          def substitution(content:, property_definition:, **_additional_args)
            format(property_definition&.dig('default_value', 'substitute_string').to_s, id: content&.id).presence
          end

          def current_user(property_definition:, current_user:, **_additional_args)
            return if property_definition&.dig('default_value', 'condition').present? && !property_definition.dig('default_value', 'condition').all? { |k, v| send("condition_#{k}", current_user, v) }

            user_string(current_user)
          end

          private

          def user_string(user)
            return if user.nil?

            "#{user.given_name} #{user.family_name} <#{user.email}>".squish
          end

          def condition_rank(user, rank)
            user&.is_rank?(rank.to_i)
          end
        end
      end
    end
  end
end
