# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      module Delete
        include Functions

        def self.process(utility_object:, data:)
          return if data.blank?
          Functions.delete(utility_object: utility_object, data: data)
        end

        def self.filter(data, external_system)
          Functions.filter(data: data, external_system: external_system, method_name: name.demodulize.underscore)
        end
      end
    end
  end
end
