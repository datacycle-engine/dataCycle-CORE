# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module OpenApi
    # Drift guard between the two hand-maintained representations of the v4
    # content filter:
    #   * the OpenAPI documentation — OpenApi::Schemas::Filters#filter (components/schemas)
    #   * the request validation    — MasterData::Contracts::BaseContract::FILTER
    #
    # Both are written by hand and mirror ApiService#apply_filters; nothing
    # generates one from the other. So a top-level filter key added to one file
    # and forgotten in the other drifts silently. This test fails the build the
    # moment the two key sets diverge in an UNEXPECTED way, forcing the author to
    # touch both files (or to consciously record the difference below).
    #
    # The two representations legitimately differ on a small, KNOWN set of keys —
    # each is listed with the reason it exists. The second test also fails if one
    # of those exceptions disappears (a stale allowlist entry), so the list can
    # never rot into a rubber stamp.
    class FiltersContractParityTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # Documented in OpenAPI, intentionally NOT validated by the contract.
      OPENAPI_ONLY = [
        # Recursive branches: each nests the whole filter again. dry-schema cannot
        # express a self-referential schema, so the contract cannot validate them.
        'graph', 'union', 'linked',
        # Generic per-attribute map (filter[attribute][<name>]…). The contract
        # validates the concrete attribute keys individually instead (CONTRACT_ONLY).
        'attribute'
      ].freeze

      # Validated by the contract, intentionally NOT surfaced as dedicated top-level
      # keys in OpenAPI — these are the concrete attribute/relation filters that the
      # OpenAPI doc folds into the generic `attribute` map above.
      CONTRACT_ONLY = ['dct:deleted', 'slug', 'skos:broader', 'skos:ancestors'].freeze

      # Top-level keys of the OpenAPI filter object (components/schemas → Filter).
      def openapi_keys
        DataCycleCore::OpenApi::Schemas::Filters.filter['properties'].keys.map(&:to_s)
      end

      # Top-level keys the validation contract accepts for `filter`.
      def contract_keys
        DataCycleCore::MasterData::Contracts::BaseContract::FILTER.key_map.map { |key| key.name.to_s }
      end

      test 'shared filter keys are identical in the OpenAPI doc and the validation contract' do
        shared_openapi = openapi_keys - OPENAPI_ONLY
        shared_contract = contract_keys - CONTRACT_ONLY

        missing_in_contract = (shared_openapi - shared_contract).sort
        missing_in_openapi = (shared_contract - shared_openapi).sort

        assert(missing_in_contract.empty? && missing_in_openapi.empty?, <<~MSG)
          The v4 filter keys drifted between the OpenAPI doc and the validation contract.

          In OpenApi::Schemas::Filters#filter but NOT in BaseContract::FILTER:
            #{missing_in_contract.inspect}
          In BaseContract::FILTER but NOT in OpenApi::Schemas::Filters#filter:
            #{missing_in_openapi.inspect}

          Add the key to BOTH files. If the difference is intentional, record it in
          OPENAPI_ONLY / CONTRACT_ONLY in this test (#{__FILE__}) with a reason.
        MSG
      end

      test 'the known-difference allowlists are not stale' do
        stale_openapi_only = (OPENAPI_ONLY - (openapi_keys - contract_keys)).sort
        stale_contract_only = (CONTRACT_ONLY - (contract_keys - openapi_keys)).sort

        assert_empty(stale_openapi_only,
                     "OPENAPI_ONLY lists keys that are no longer OpenAPI-only: #{stale_openapi_only.inspect}. " \
                     'Remove them (they are now either in both files or gone).')
        assert_empty(stale_contract_only,
                     "CONTRACT_ONLY lists keys that are no longer contract-only: #{stale_contract_only.inspect}. " \
                     'Remove them (they are now either in both files or gone).')
      end
    end
  end
end
