# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module ApiRenderer
    class TimeseriesRendererTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # A content stand-in whose timeseries property returns a real (empty)
      # Timeseries relation, so the renderer builds and executes valid SQL.
      def content_double(property_names: ['my_ts'], query: DataCycleCore::Timeseries.all)
        content = Object.new
        content.define_singleton_method(:timeseries_property_names) { |*| property_names }
        content.define_singleton_method(:name) { 'TS Content' }
        content.define_singleton_method(:id) { '00000000-0000-0000-0000-000000000000' }
        content.define_singleton_method(:my_ts) { query }
        content
      end

      def renderer(**)
        DataCycleCore::ApiRenderer::TimeseriesRenderer.new(content: content_double, timeseries: 'my_ts', **)
      end

      test 'render raises when the timeseries property is unknown' do
        subject = DataCycleCore::ApiRenderer::TimeseriesRenderer.new(content: content_double(property_names: []), timeseries: 'my_ts')

        assert_raises(DataCycleCore::ApiRenderer::Error::RendererError) { subject.render(:json) }
      end

      test 'render raises for an unknown group_by parameter' do
        subject = renderer(group_by: 'bogus_group')

        assert_raises(DataCycleCore::ApiRenderer::Error::RendererError) { subject.render(:json) }
      end

      test 'render raises for an unsupported format/dataFormat combination' do
        subject = renderer(data_format: 'weird')

        assert_raises(DataCycleCore::ApiRenderer::Error::RendererError) { subject.render(:json) }
      end

      test 'renders a json array for the default grouping' do
        assert_nothing_raised { renderer.render(:json) }
      end

      test 'renders a csv array' do
        assert_nothing_raised { renderer(data_format: 'array').render(:csv) }
      end

      test 'renders a json object' do
        assert_nothing_raised { renderer(data_format: 'object').render(:json) }
      end

      test 'renders an aggregated grouping with a time window' do
        subject = renderer(group_by: 'sum_day', time: { in: { min: '2024-01-01T00:00:00', max: '2024-12-31T00:00:00' } })

        assert_nothing_raised { subject.render(:json) }
      end

      test 'legacy group_by without an aggregate prefix is accepted' do
        # 'day' is a legacy group → prefixed with sum_ internally (the renderer
        # mutates the string via #prepend, so it must not be frozen)
        assert_nothing_raised { renderer(group_by: +'day').render(:json) }
      end
    end
  end
end
