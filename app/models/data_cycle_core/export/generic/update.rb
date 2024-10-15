# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module Update
        def self.process(utility_object:, data:)
          return if data.blank?

          Functions.enqueue(utility_object:, data:)
        end

        def self.filter(data, external_system)
          Functions.filter(data:, external_system:, method_name: name.demodulize.underscore)
        end
      end
    end
  end
end
