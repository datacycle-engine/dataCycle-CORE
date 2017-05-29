module DataCycleCore
  module Filter
    class PlaceQueryBuilder < QueryBuilder

      def initialize(query = nil, translation = false, classification_alias = false)
        @translation = translation
        @classification_alias = classification_alias
        @query = query || Place.unscoped.distinct
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

    private

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

    end
  end
end
