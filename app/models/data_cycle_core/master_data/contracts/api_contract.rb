# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      class ApiContract < BaseContract
        params(BASE, EXTERNAL_IDENTITY, BASE_JSON_API, BASE_MVT_API, WATCHLIST, CLASSIFICATIONS, CONTENT) do
          optional(:page).hash(PAGE)
          optional(:section).hash(SECTION)
          optional(:filter).hash(FILTER)
          optional(:time).hash(TIME_FILTER)
          optional(:groupBy).filled(:string)
        end
      end
    end
  end
end
