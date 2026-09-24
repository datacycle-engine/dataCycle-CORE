# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Covers the one assertion of FilterDescription that is no longer reachable through the tools:
    # since the tool schemas reject non-UUIDs (Mcp::UUID_CONSTRAINTS), a concept NAME no longer
    # arrives there -- so the integration test CANNOT check the case any more.
    #
    # It must not stay unchecked all the same. FilterDescription builds applied_filters from the RAW
    # arguments and does not depend on the route through a tool schema; without the check in
    # #descendant_ids_for the ::uuid[] cast fails with a PG::InvalidTextRepresentation -- out of the
    # very description meant to explain a wrong input.
    class FilterDescriptionTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # A tree of its own per run (a SecureRandom name), so the assertions do not hang on the seed
      # data's classification trees -- as in GeoScopeTest.
      before(:all) do
        concept_scheme = DataCycleCore::ConceptScheme.create!(
          name: SecureRandom.hex(10),
          external_system_id: DataCycleCore::ExternalSystem.first.id
        )
        # Through insert_all_concepts_by_path, because concept_paths are created from
        # concepts/concept_links by trigger -- without them the subtree filter finds nothing.
        concept_scheme.insert_all_concepts_by_path([{ path: ['Oberbegriff'] }])
        concept_scheme.insert_all_concepts_by_path([{ path: ['Oberbegriff', 'Unterbegriff'] }])

        @parent = DataCycleCore::Concept.by_full_paths("#{concept_scheme.name} > Oberbegriff").first
      end

      test 'a value that is no uuid is reported as unresolved instead of breaking the query' do
        group = describe_group(['wandern'])

        assert_equal ['wandern'], group[:unresolved_ids]
        assert_empty group[:concepts]
        assert_nil group[:subtree_concept_count]
      end

      # The counter-check to the test above: the non-UUID may sort out ONLY ITSELF. An early exit
      # for the whole list would not be visible from the first test -- that one is green when the
      # subtree is no longer determined at all, and the response would silently lose the concepts
      # include_subtree pulls in.
      test 'a value that is no uuid does not suppress the subtree of the valid ids beside it' do
        group = describe_group([@parent.id, 'wandern'])

        assert_equal ['wandern'], group[:unresolved_ids]
        assert_equal [@parent.id], group[:concepts].pluck(:id)
        assert_equal 1, group[:subtree_concept_count]
      end

      private

      def describe_group(ids)
        DataCycleCore::Mcp::FilterDescription
          .new(arguments: { classification_alias_ids: ids }, groups: [ids], include_subtree: true)
          .to_h
          .dig(:classification_groups, 0)
      end
    end
  end
end
