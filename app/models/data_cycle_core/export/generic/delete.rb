# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module Delete
        def self.process(utility_object:, data:)
          return if data.blank?

          Functions.delete(utility_object:, data:)
        end

        def self.filter(_data, _external_system)
          true
        end
      end
    end
  end
end
