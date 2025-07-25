# frozen_string_literal: true

module DataCycleCore
  module Filter
    class QueryBuilder
      extend Forwardable
      include Enumerable
      include DataCycleCore::Common::ArelBuilder

      attr_reader :query, :include_embedded
      def_delegators :query, :to_a, :to_sql, :each, :page, :includes, :all, :select, :map, :except
      TERMINAL_METHODS = [:count, :size, :pluck, :first, :second, :third, :fourth, :fifth, :forty_two, :last].freeze
      def_delegators :query, *TERMINAL_METHODS

      def limit(number)
        reflect(@query.limit(number))
      end

      def take(number)
        reflect(@query.limit(number))
      end

      def offset(number)
        reflect(@query.offset(number))
      end

      def skip(number)
        reflect(@query.offset(number))
      end

      def where(*)
        reflect(@query.where(*))
      end

      def not(*)
        reflect(@query.not(*))
      end

      def order(*)
        reflect(@query.order(*))
      end

      def sanitize_sql(sql_array)
        ActiveRecord::Base.send(:sanitize_sql_array, sql_array)
      end

      def none
        reflect(@query.none)
      end

      private

      def get_point(longitude, latitude)
        Arel::Nodes::NamedFunction.new('ST_GeomFromEWKT', ["SRID=4326;POINT (#{longitude} #{latitude})"])
      end

      def get_box(point1, point2)
        Arel::Nodes::NamedFunction.new('ST_MakeBox2D', [point1, point2])
      end

      def st_makeenvelope(xmin, ymin, xmax, ymax, srid)
        Arel::Nodes::NamedFunction.new('ST_MakeEnvelope', [
                                         Arel::Nodes::SqlLiteral.new(xmin.to_s),
                                         Arel::Nodes::SqlLiteral.new(ymin.to_s),
                                         Arel::Nodes::SqlLiteral.new(xmax.to_s),
                                         Arel::Nodes::SqlLiteral.new(ymax.to_s),
                                         Arel::Nodes::SqlLiteral.new(srid.to_s)
                                       ])
      end

      def st_dwithin(geom1, geom2, distance)
        Arel::Nodes::NamedFunction.new('ST_DWithin', [geom1, geom2, distance])
      end

      def st_transform(geom, srid)
        Arel::Nodes::NamedFunction.new('ST_Transform', [geom, srid])
      end

      def st_setsrid(geom, srid)
        Arel::Nodes::NamedFunction.new('ST_SetSRID', [geom, srid])
      end

      def st_makepoint(x, y)
        Arel::Nodes::NamedFunction.new('ST_MakePoint', [Arel::Nodes::SqlLiteral.new(x), Arel::Nodes::SqlLiteral.new(y)])
      end

      def st_contains(geom1, geom2)
        Arel::Nodes::NamedFunction.new('ST_Contains', [geom1, geom2])
      end

      def st_intersects(geom1, geom2)
        Arel::Nodes::NamedFunction.new('ST_Intersects', [geom1, geom2])
      end

      def st_disjoint(geom1, geom2)
        Arel::Nodes::NamedFunction.new('ST_Disjoint', [geom1, geom2])
      end

      def contains(geo1, geo2)
        Arel::Nodes::InfixOperation.new('@', geo1, geo2)
      end

      def intersects(geo1, geo2)
        overlap(geo1, geo2)
      end

      def in_range(range, date)
        Arel::Nodes::InfixOperation.new('@>', range, date)
      end

      def contained_in_range(range, date)
        Arel::Nodes::InfixOperation.new('<@', range, date)
      end

      def overlap(range_l, range_r)
        Arel::Nodes::InfixOperation.new('&&', range_l, range_r)
      end

      def subtract(value1, value2)
        Arel::Nodes::Subtraction.new(value1, value2)
      end

      def in_json(json, key)
        Arel::Nodes::InfixOperation.new('->>', json, quoted(key))
      end

      def any(set)
        Arel::Nodes::UnaryOperation.new('ANY', Arel::Nodes::Grouping.new(set))
      end

      def tstzrange(ts_l, ts_h, border = '[]')
        Arel::Nodes::NamedFunction.new('tstzrange', [ts_l, ts_h, quoted(border)])
      end

      def tsrange(ts_l, ts_h, border = '[]')
        Arel::Nodes::NamedFunction.new('tsrange', [ts_l, ts_h, quoted(border)])
      end

      def upper_range(range)
        Arel::Nodes::NamedFunction.new('upper', [range])
      end

      def infinity
        quoted('infinity')
      end

      def interval(interval)
        Arel::Nodes::SqlLiteral.new("interval '#{interval}'")
      end

      def cast_rrule(rrule_string)
        Arel::Nodes::NamedFunction.new(
          'CAST', [
            Arel::Nodes::As.new(
              quoted(rrule_string),
              Arel::Nodes::SqlLiteral.new('rrule')
            )
          ]
        )
      end

      def cast_ts(date)
        Arel::Nodes::NamedFunction.new(
          'CAST', [
            Arel::Nodes::As.new(
              quoted(date),
              Arel::Nodes::SqlLiteral.new('timestamp without time zone')
            )
          ]
        )
      end

      def cast_tstz(date)
        date = date.iso8601 if date.acts_like?(:time) # Ensure date is in ISO 8601 format to keep time zone information
        Arel::Nodes::NamedFunction.new(
          'CAST', [
            Arel::Nodes::As.new(
              quoted(date),
              Arel::Nodes::SqlLiteral.new('timestamp with time zone')
            )
          ]
        )
      end

      def cast_date(date)
        Arel::Nodes::NamedFunction.new(
          'CAST', [
            Arel::Nodes::As.new(
              quoted(date),
              Arel::Nodes::SqlLiteral.new('date')
            )
          ]
        )
      end

      def cast_geography(geom)
        Arel::Nodes::NamedFunction.new(
          'CAST', [
            Arel::Nodes::As.new(
              geom,
              Arel::Nodes::SqlLiteral.new('geography')
            )
          ]
        )
      end

      def cast(string, type_string)
        Arel::Nodes::NamedFunction.new(
          'CAST', [
            Arel::Nodes::As.new(
              string,
              Arel::Nodes::SqlLiteral.new(type_string)
            )
          ]
        )
      end

      def geometry_type(column)
        Arel::Nodes::NamedFunction.new(
          'GeometryType', [
            column
          ]
        )
      end

      def classification_content
        DataCycleCore::ClassificationContent.arel_table
      end

      def classification
        Classification.arel_table
      end

      def classification_tree
        ClassificationTree.arel_table
      end

      def classification_group
        ClassificationGroup.arel_table
      end

      def classification_alias
        ClassificationAlias.arel_table
      end

      def watch_list_data_hash
        DataCycleCore::WatchListDataHash.arel_table
      end

      def content_content
        DataCycleCore::ContentContent.arel_table
      end

      def content_content_link
        DataCycleCore::ContentContent::Link.arel_table
      end

      def search
        DataCycleCore::Search.arel_table
      end

      def schedule
        DataCycleCore::Schedule.arel_table
      end

      def thing
        DataCycleCore::Thing.arel_table
      end

      def thing_history_table
        DataCycleCore::Thing::History.arel_table
      end

      def thing_translations
        DataCycleCore::Thing::Translation.arel_table
      end

      def classification_polygon
        DataCycleCore::ClassificationPolygon.arel_table
      end

      def duplicate_candidate
        DataCycleCore::Thing::DuplicateCandidate.arel_table
      end

      def thing_duplicate
        DataCycleCore::ThingDuplicate.arel_table
      end

      def external_system_sync
        DataCycleCore::ExternalSystemSync.arel_table
      end

      def subscription
        DataCycleCore::Subscription.arel_table
      end

      def thing_template
        DataCycleCore::ThingTemplate.arel_table
      end

      def pg_dict_mapping
        DataCycleCore::PgDictMapping.arel_table
      end

      def user_table
        DataCycleCore::User.arel_table
      end

      def ccc_table
        DataCycleCore::CollectedClassificationContent.arel_table
      end

      def geometries_table
        DataCycleCore::Geometry.arel_table
      end

      def generate_thing_alias
        thing.alias("th_#{SecureRandom.hex(5)}")
      end

      def reflect(query)
        self.class.new(
          locale: @locale,
          query: query,
          include_embedded: include_embedded
        )
      end
    end
  end
end
