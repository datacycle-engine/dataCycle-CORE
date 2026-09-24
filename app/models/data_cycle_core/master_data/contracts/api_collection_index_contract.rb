# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      # Params contract for +Api::V4::StoredFiltersController#index+ (GET /api/v4/endpoints):
      # the list shape (BASE + BASE_JSON_API + page + section) shared with
      # ApiDuplicatesContract, covering everything the document advertises for getEndpoints
      # (OpenApi::Paths::Common::LIST_PARAM_NAMES).
      #
      # Its sibling ApiCollectionContract cannot serve #index, because the :endpoint it
      # requires is what #create resolves the source collection from - #index takes no
      # source and would be rejected outright.
      class ApiCollectionIndexContract < BaseContract
        params(BASE, BASE_JSON_API) do
          optional(:page).hash(PAGE)
          optional(:section).hash(SECTION)
        end
      end
    end
  end
end
