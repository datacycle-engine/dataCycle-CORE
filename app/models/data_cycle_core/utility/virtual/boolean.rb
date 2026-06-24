# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Boolean
        class << self
          def by_assigned_classification(content:, virtual_definition:, **_args)
            classification_path = virtual_definition.dig('virtual', 'path')

            content.full_classification_aliases.any? { |c| c.full_path == classification_path }
          end
        end
      end
    end
  end
end
