# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Geo
    # Coverage for the Geo::BaseRenderer: the abstract main_sql and the conditional
    # include builders (slug, image incl. thumbnailUrl, internal content score)
    # reached through include_config. SQL is only built, never executed.
    class BaseRendererCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      test 'main_sql is not implemented on the base renderer' do
        assert_raises(NotImplementedError) { DataCycleCore::Geo::BaseRenderer.new.main_sql }
      end

      test 'include_config builds slug, image and content-score include definitions' do
        renderer = DataCycleCore::Geo::BaseRenderer.new(
          include_parameters: [['dc:slug'], ['image', 'thumbnailUrl'], ['dc:contentScore']]
        )

        identifiers = renderer.include_config('things').pluck(:identifier)

        assert_includes(identifiers, '"dc:slug"')
        assert_includes(identifiers, '"image"')
        assert_includes(identifiers, '"dc:contentScore"')
      end

      test 'include_config builds the dc:iconId include from the stored primary icon relation' do
        renderer = DataCycleCore::Geo::BaseRenderer.new(include_parameters: [['dc:iconId']])

        icon = renderer.include_config('things').find { |c| c[:identifier] == '"dc:iconId"' }

        assert(icon)
        assert_includes(icon[:joins], "classification_contents.relation = 'primary_icon_classifications'")
        assert_includes(icon[:joins], "'api' = ANY(concept_schemes.visibility)")
      end

      test 'dc:iconId include is also recognized via fields and filters by requested trees' do
        tree_id = SecureRandom.uuid
        renderer = DataCycleCore::Geo::BaseRenderer.new(
          fields_parameters: [['dc:iconId']],
          classification_trees_parameters: [tree_id]
        )

        icon = renderer.include_config('things').find { |c| c[:identifier] == '"dc:iconId"' }

        assert(icon)
        assert_includes(icon[:joins], "concepts.concept_scheme_id IN ('#{tree_id}')")
      end
    end
  end
end
