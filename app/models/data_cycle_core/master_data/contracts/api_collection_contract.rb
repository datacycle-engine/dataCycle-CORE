# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      class ApiCollectionContract < BaseContract
        COLLECTION_PARAMS = Dry::Schema.Params do
          required(:endpoint).filled(:string)
          optional(:collection).hash do
            optional(:@type).filled(:string, included_in?: [WatchList::API_V4_TYPE])
            optional(:name).filled(:string)
            # optional(:validFrom).filled(:date_time)
            # optional(:validUntil).filled(:date_time)
          end
        end

        params(BASE, BASE_JSON_API, COLLECTION_PARAMS) do
          optional(:section).hash(SECTION)
          optional(:filter).hash(FILTER)
        end
      end
    end
  end
end
