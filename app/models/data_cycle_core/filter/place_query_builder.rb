module DataCycleCore
  module Filter
    class PlaceQueryBuilder
      extend Forwardable
      include Enumerable

      attr_reader :query,:uuid
      def_delegators :@query, :to_a, :to_sql, :each, :order
      TERMINAL_METHODS = [:count, :pluck,
        :first, :second, :third, :fourth, :fifth, :forty_two, :last]
      def_delegators :@query, *TERMINAL_METHODS

      def initialize(uuid, query = nil, translation = false, classification_alias = false)
        @translation = translation
        @classification_alias = classification_alias
        @uuid = uuid
        @query = query || Place.unscoped.where(place[:external_source_id].eq(uuid)).distinct
      end

    # helper for paging
      def take(number)
        reflect(
          @query.take(number)
        )
      end

      def limit(number)
        take(number)
      end

      def skip(number)
        reflect(
          @query.skip(number)
        )
      end
      def offset(number)
        skip(number)
      end

    # filters
      def with_name(name)
        unless @translation # see if joins are necessary
          @query = join_place_translation
          @translation = true
        end
        reflect(
          @query.where(
            place_translation[:name].matches("%#{name}%")
          )
        )
      end

      def within_area(longitude1, latitude1, longitude2, latitude2)
        bbox = get_box(get_point(longitude1, latitude1), get_point(longitude2, latitude2))
        reflect(
          @query.where(contains(place[:location], bbox))
        )
      end

      def within_distance(longitude, latitude, distance_km)
        distance = distance_km * 180 / Math::PI / 6378.137
        reflect(
          @query.where(st_distance(place[:location], get_point(longitude,latitude)).lt(distance))
        )
      end

      def with_classification_alias(name)
        unless @classification_alias # see if joins are necessary
          @query = join_classification_alias
          @classification_alias = true
        end
        reflect(
          @query.where(
            classification_alias[:name].matches("%#{name}%")
          )
        )
      end

      def with_classification_alias_ids(ids = nil)
        unless @classification_alias # see if joins are necessary
          @query = join_classification_alias
          @classification_alias = true
        end
        # ids = ['0543d553-3c2d-4f49-bf19-5d2e59a15d82', '5ae2c5f2-1534-4800-b1fb-216b789cf9cb']
        ids_string = "('"+ids.join("', '")+"')"
        sql = <<-eos
          WITH RECURSIVE children(top_id) AS
          (
            SELECT classification_alias_id FROM classification_trees
              WHERE parent_classification_alias_id IN #{ids_string}
          UNION ALL
            SELECT t.classification_alias_id from children, classification_trees t
              WHERE t.parent_classification_alias_id = children.top_id
          )
          SELECT * FROM children;
        eos
        result = ActiveRecord::Base.connection.execute(sql)
        classification_ids = ids + result.map{|item| item["top_id"]} # parents + children
        reflect(
          @query.where(
            classification_alias[:id].in(classification_ids)
          )
        )
      end

    private

    # custom function helper
      def get_point(longitude,latitude)
        Arel::Nodes::NamedFunction.new("ST_GeomFromEWKT", ["SRID=4326;POINT (#{longitude} #{latitude})"])
      end

      def get_box(point1, point2)
        Arel::Nodes::NamedFunction.new("ST_MakeBox2D", [point1, point2])
      end

      def st_distance(point1, point2)
        Arel::Nodes::NamedFunction.new("ST_Distance", [point1, point2])
      end

      def contains(geo1, geo2)
        Arel::Nodes::InfixOperation.new("@", geo1, geo2)
      end

    # joins
      def join_place_translation
        @query.joins(place.join(place_translation)
          .on(place[:id].eq(place_translation[:place_id]))
          .join_sources
        )
      end

      def join_classification_place
        @query.joins(place.join(classification_place)
          .on(place[:id].eq(classification_place[:place_id]))
          .join_sources
        )
      end

      def join_classification
        join_classification_place.joins(classification_place.join(classification)
          .on(classification_place[:classification_id].eq(classification[:id]))
          .join_sources
        )
      end

      def join_classification_group
        join_classification.joins(classification.join(classification_group)
          .on(classification[:id].eq(classification_group[:classification_id]))
          .join_sources
        )
      end

      def join_classification_alias
        join_classification_group.joins(classification_group.join(classification_alias)
          .on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
          .join_sources
        )
      end

    # chain method for Builder pattern
      def reflect(query)
        self.class.new(@uuid, query, @translation, @classification_alias)
      end

    # define Arel-tables
      def place
        Place.arel_table
      end

      def place_translation
        PlaceTranslation.arel_table
      end

      def classification_place
        ClassificationPlace.arel_table
      end

      def classification
        Classification.arel_table
      end

      def classification_group
        ClassificationGroup.arel_table
      end

      def classification_alias
        ClassificationAlias.arel_table
      end

    end
  end
end
