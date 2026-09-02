# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      # Params contract for +Api::V4::DuplicatesController+. +@id+ names the duplicate when marking a
      # pair, +duplicate_id+ comes from the route for merge/false_positive, +falsePositive+ switches
      # the listing to the dismissed pairs. All optional - the per-action checks live in the
      # controller.
      class ApiDuplicatesContract < BaseContract
        DUPLICATE_PARAMS = Dry::Schema.Params do
          optional(:@id).filled(:string)
          optional(:duplicate_id).filled(:string)
          optional(:falsePositive).filled(:bool)
        end

        params(BASE, BASE_JSON_API, DUPLICATE_PARAMS) do
          optional(:page).hash(PAGE)
          optional(:section).hash(SECTION)
        end
      end
    end
  end
end
