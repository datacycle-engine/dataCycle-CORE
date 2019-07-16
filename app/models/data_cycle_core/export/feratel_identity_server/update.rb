# frozen_string_literal: true

module DataCycleCore
  module Export
    module FeratelIdentityServer
      module Update
        include Functions

        def self.process(utility_object:, data:)
          return if data.blank?
          Functions.update(utility_object: utility_object, data: data)
        end

        def self.filter(data, _external_system)
          data.provider == 'openid_connect' && data.uid.present?
        end
      end
    end
  end
end
