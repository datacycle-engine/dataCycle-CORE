# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # The response of the three renderer tools (statistics, timeseries, elevation_profile),
    # normalised to a hash and thinned to MAX_POINTS. All three answer in the same shape --
    # { 'data' => [...], 'meta' => {...} } from one json_build_object -- which is why one class
    # serves them instead of a cap per tool.
    #
    # Thinned HERE and not in the renderers: those serve the REST API as well, where a client asks
    # for a format and reads the response as a stream or a file. A tool result instead lands in a
    # model's context in one piece, and the renderers put no ceiling on it -- a tour recorded every
    # few metres or an hourly series over years delivers tens of thousands of points, which fills
    # the context before the model reaches the question it was asked.
    class SeriesPayload
      # Enough to keep the shape of a profile or a series readable, far below what exhausts a
      # context: 500 points of an elevation profile (x, y and a coordinate pair each) are some 30 kB.
      MAX_POINTS = 500

      # @param result [Hash, String] the renderer's response. Depending on the renderer it is either
      #   a hash OR a finished JSON string; passed through unchanged, the string would arrive at the
      #   client doubly serialized -- JSON text inside a JSON field instead of a structured object an
      #   LLM can evaluate.
      def initialize(result)
        @payload = result.is_a?(String) ? JSON.parse(result) : result
      end

      # point_count and downsampled beside the thinned data, so the thinning is legible in the
      # payload too and not only in the envelope's warning (as Mcp::FilterDescription keeps
      # subtree_concepts_truncated beside its sample).
      def to_h
        return @payload unless downsampled?

        @payload.merge(
          'data' => sampled,
          'meta' => (@payload['meta'] || {}).merge('point_count' => points.size, 'downsampled' => true)
        )
      end

      # nil when nothing was dropped -- Tools::Base#add_warning discards it then.
      def warning
        return unless downsampled?

        DataCycleCore::Mcp::Translations.t('warnings.downsampled_series', total: points.size, returned: sampled.size)
      end

      private

      # [] for anything that is not the shape above, which then passes through untouched: a renderer
      # answering differently is not something to silently reshape here.
      def points
        @points ||= @payload.is_a?(::Hash) ? Array.wrap(@payload['data']) : []
      end

      def downsampled?
        points.size > MAX_POINTS
      end

      # MAX_POINTS evenly spaced points including BOTH ends, not the first MAX_POINTS: a truncated
      # profile loses its end, so the summit of a tour or the latest value of a series would
      # disappear while the points that remain still read as a complete answer.
      #
      # Spaced by index rather than by a whole-numbered step, which only ever halves: at 501 points
      # `each_slice(2)` would answer with 251 and throw away half the series to cross a ceiling
      # overshot by one.
      def sampled
        @sampled ||= (0...MAX_POINTS).map { |i| points[(i * (points.size - 1) / (MAX_POINTS - 1.0)).round] }
      end
    end
  end
end
