# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Unit tests for the point ceiling of the renderer tools. Against literal payloads rather than a
    # real renderer: the shape is the contract between the two, and a series long enough to be
    # thinned would otherwise have to be seeded first.
    class SeriesPayloadTest < DataCycleCore::TestCases::ActiveSupportTestCase
      MAX = DataCycleCore::Mcp::SeriesPayload::MAX_POINTS

      def series(size)
        { 'data' => (1..size).map { |i| { 'x' => i, 'y' => i * 2 } }, 'meta' => { 'scaleX' => 'm' } }
      end

      test 'a series within the ceiling passes through unchanged and without a warning' do
        payload = DataCycleCore::Mcp::SeriesPayload.new(series(MAX))

        assert_equal series(MAX), payload.to_h
        assert_nil payload.warning
      end

      test 'a finished JSON string is parsed' do
        assert_equal series(3), DataCycleCore::Mcp::SeriesPayload.new(series(3).to_json).to_h
      end

      # The ceiling is what the finding is about: unthinned, a tour recorded every few metres fills
      # the client's context in a single call.
      test 'a longer series is thinned to the ceiling' do
        result = DataCycleCore::Mcp::SeriesPayload.new(series(MAX * 10)).to_h

        assert_equal MAX, result['data'].size
      end

      # A whole-numbered step only ever halves: at one point over the ceiling it would answer with
      # MAX / 2 and drop half the series for an overshoot of one.
      test 'a series just over the ceiling keeps all but the overshoot' do
        result = DataCycleCore::Mcp::SeriesPayload.new(series(MAX + 1)).to_h

        assert_equal MAX, result['data'].size
      end

      # Both ends survive, because a truncated profile loses its end: the summit of a tour and the
      # latest value of a series would disappear while the remaining points still read as complete.
      test 'the thinned series keeps the first and the last point' do
        result = DataCycleCore::Mcp::SeriesPayload.new(series(MAX * 10)).to_h

        assert_equal({ 'x' => 1, 'y' => 2 }, result['data'].first)
        assert_equal({ 'x' => MAX * 10, 'y' => MAX * 20 }, result['data'].last)
      end

      # Legible in the payload as well as in the envelope: meta keeps the original size beside the
      # sample, as Mcp::FilterDescription keeps subtree_concepts_truncated beside its own.
      test 'the thinning is recorded in meta and keeps the renderer keys' do
        result = DataCycleCore::Mcp::SeriesPayload.new(series(MAX * 10)).to_h

        assert_equal MAX * 10, result.dig('meta', 'point_count')
        assert result.dig('meta', 'downsampled')
        assert_equal 'm', result.dig('meta', 'scaleX')
      end

      test 'a thinned series warns, naming both counts' do
        payload = DataCycleCore::Mcp::SeriesPayload.new(series(MAX * 10))

        assert_includes payload.warning, (MAX * 10).to_s
        assert_includes payload.warning, payload.to_h['data'].size.to_s
      end

      # A renderer answering in a different shape is passed through, not silently reshaped.
      test 'a payload without a data array is left alone' do
        assert_equal({ 'error' => 'no elevation data' }, DataCycleCore::Mcp::SeriesPayload.new({ 'error' => 'no elevation data' }).to_h)
        assert_nil DataCycleCore::Mcp::SeriesPayload.new({ 'data' => nil }).warning
      end
    end
  end
end
