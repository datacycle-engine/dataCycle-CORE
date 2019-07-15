# frozen_string_literal: true

module DataCycleCore
  module Export
    module FeratelIdentityServer
      module Create
        include Functions

        def self.process(utility_object:, data:)
          return if data.blank?
          Functions.create(utility_object: utility_object, data: data)
        end

        def self.filter(_data, _external_system)
          true
        end
      end
    end
  end
end
