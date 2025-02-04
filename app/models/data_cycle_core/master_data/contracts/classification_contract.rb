# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      class ClassificationContract < BaseContract
        FACET_PARAMS = Dry::Schema.Params do
          optional(:min_count_with_subtree).filled(:integer)
          optional(:min_count_without_subtree).filled(:integer)
          optional(:minCountWithSubtree).filled(:integer)
          optional(:minCountWithoutSubtree).filled(:integer)
        end

        params(BASE, EXTERNAL_IDENTITY, BASE_JSON_API, BASE_MVT_API, WATCHLIST, CLASSIFICATIONS, CONTENT, FACET_PARAMS) do
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
