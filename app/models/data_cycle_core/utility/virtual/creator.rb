# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Creator
        class << self
          def by_attribute_key(content:, virtual_definition:, **_args)
            return if virtual_definition.dig('virtual', 'key').blank?

            content&.created_by_user.try(virtual_definition.dig('virtual', 'key'))
          end
        end
      end
    end
  end
end
