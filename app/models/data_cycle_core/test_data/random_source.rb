# frozen_string_literal: true

module DataCycleCore
  module TestData
    # Stdlib-only random value source. Faker is dev-only (GemfileCore group :development)
    # and not loadable in production, so the generator must not depend on it.
    module RandomSource
      WORDS = [
        'alpen', 'anger', 'auen', 'berg', 'blume', 'bogen', 'brunnen', 'dorf', 'eiche',
        'fels', 'feld', 'fluss', 'garten', 'gipfel', 'hain', 'halde', 'hof', 'insel',
        'kanal', 'kapelle', 'licht', 'moor', 'nebel', 'quelle', 'rast', 'see', 'sonne',
        'steg', 'stein', 'tal', 'teich', 'ufer', 'wald', 'wasser', 'weg', 'wiese',
        'wolke', 'zauber', 'zone'
      ].freeze

      module_function

      # A single random word from the pool.
      def word
        WORDS.sample
      end

      # `count` random words joined by spaces (at least one).
      def words(count)
        Array.new([count.to_i, 1].max) { word }.join(' ')
      end

      # A short capitalized title of 2-4 words.
      def title
        words(rand(2..4)).split.map(&:capitalize).join(' ')
      end

      # A single capitalized sentence ending in a period.
      def sentence
        "#{words(rand(6..12)).capitalize}."
      end

      # `sentences` sentences joined into one paragraph.
      def paragraph(sentences = 2)
        Array.new(sentences) { sentence }.join(' ')
      end

      # A string whose plain-text length satisfies the optional min/max bounds.
      def constrained_string(min: nil, max: nil, as_title: false)
        min = min&.to_i
        max = max&.to_i
        text = as_title ? title : paragraph(rand(1..2))
        text = "#{text} #{words(20)}" while min && text.length < min
        text = text[0, max].strip if max && text.length > max
        text = text.ljust(min, '.') if min && text.length < min
        text
      end

      # A random integer within [min, max].
      def integer(min: 1, max: 1000)
        min = min.to_i
        max = [max.to_i, min].max
        rand(min..max)
      end

      # A random float within [min, max], rounded to two decimals.
      def decimal(min: 0, max: 1000)
        min = min.to_f
        max = [max.to_f, min].max
        ((rand * (max - min)) + min).round(2)
      end

      # A random boolean.
      def boolean
        [true, false].sample
      end

      # A random date on/after `after` (or 2020-01-01), within ~3 years.
      def date(after: nil)
        (parse_date(after) || Date.new(2020, 1, 1)) + rand(0..1095)
      end

      # A random datetime on/after `after` (or now), within ~1 year.
      def datetime(after: nil)
        (parse_time(after) || Time.zone.now) + rand(0..365).days + rand(0..86_399).seconds
      end

      # Random WKT for the geometry type from the attribute's ui.edit.type (defaults to a point).
      def wkt(geometry_type = nil)
        case geometry_type.to_s
        when 'LineString' then "LINESTRING (#{coordinate_list(3)})"
        when 'Polygon' then "POLYGON ((#{closed_ring}))"
        when 'MultiPoint' then "MULTIPOINT (#{coordinate_pair}, #{coordinate_pair})"
        when 'MultiLineString' then "MULTILINESTRING ((#{coordinate_list(3)}))"
        when 'MultiPolygon' then "MULTIPOLYGON (((#{closed_ring})))"
        else wkt_point
        end
      end

      # Random WKT point roughly within Central Europe (lon lat, srid 4326).
      def wkt_point
        "POINT (#{coordinate_pair})"
      end

      # A single "lon lat" pair within Central Europe.
      def coordinate_pair
        "#{((rand * 7.5) + 9.5).round(6)} #{((rand * 2.7) + 46.3).round(6)}"
      end

      # `count` comma-separated coordinate pairs.
      def coordinate_list(count)
        Array.new(count) { coordinate_pair }.join(', ')
      end

      # A closed square ring (first pair repeated as the last) for a valid polygon.
      def closed_ring
        lon = ((rand * 7.5) + 9.5).round(6)
        lat = ((rand * 2.7) + 46.3).round(6)
        d = 0.01
        [[lon, lat], [lon + d, lat], [lon + d, lat + d], [lon, lat + d], [lon, lat]]
          .map { |x, y| "#{x.round(6)} #{y.round(6)}" }.join(', ')
      end

      # Parses a date, returning nil on failure.
      def parse_date(value)
        return if value.blank?

        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      # Parses a time in the current zone, returning nil on failure.
      def parse_time(value)
        return if value.blank?

        value.to_s.in_time_zone
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
