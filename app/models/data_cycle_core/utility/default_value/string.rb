# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module String
        class << self
          def substitution(**args)
            format(args.dig(:property_definition, 'default_value', 'substitute_string').to_s, id: args[:content]&.id).presence
          end
        end
      end
    end
  end
end
