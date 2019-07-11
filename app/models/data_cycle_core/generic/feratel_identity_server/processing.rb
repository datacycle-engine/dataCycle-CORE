# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelIdentityServer
      module Processing
        def self.process_user(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelIdentityServer::Transformations.user_to_organization(utility_object),
            default: { template: 'Organization' },
            config: config
          )
        end
      end
    end
  end
end
