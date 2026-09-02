# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      # Params contract for +Api::V4::ExternalConnectionsController+. A connection is addressed by
      # +propertyID+ (external system identifier, name or uuid) and +value+ (external key) — the same
      # pair the API exposes as +identifier+ PropertyValues. Both are declared optional because
      # +demote+ takes neither; the per-action presence check lives in the controller.
      #
      # The standard APIv4 parameters are taken over even though the response is a single object and
      # ignores all of them but +language+: +config.validate_keys+ would otherwise answer a request
      # that generically carries +language+ or +page+ with 400, although ApiBaseController permits
      # those keys everywhere and reads +language+ itself.
      class ApiExternalConnectionsContract < BaseContract
        EXTERNAL_CONNECTION_PARAMS = Dry::Schema.Params do
          optional(:propertyID).filled(:string)
          optional(:value).filled(:string)
        end

        params(BASE, BASE_JSON_API, EXTERNAL_CONNECTION_PARAMS) do
          optional(:page).hash(PAGE)
          optional(:section).hash(SECTION)
        end
      end
    end
  end
end
