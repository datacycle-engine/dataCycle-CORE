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
    end
  end
end
