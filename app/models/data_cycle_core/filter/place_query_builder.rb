module DataCycleCore
  module Filter
    class PlaceQueryBuilder < QueryBuilder

      def initialize(locale = 'de', query = nil)
        @locale = locale
        @query = query || Place.unscoped.distinct.
          where(template: false).includes(:watch_lists, :translations, :display_classification_aliases).
          joins(
            place.join(place_translation).
            on(place[:id].eq(place_translation[:place_id])).
            join_sources
          ).where(place_translation[:locale].eq(quoted(@locale)))
      end

    # filters
      def fulltext_search(name)
        # include textsearch on classification_aliases.name
        query = join_classification_alias2
        manager = query.where(classification_alias[:name].matches("%#{name}%"))


        reflect(
          @query.where(place[:id].in(manager).or(
            place_translation[:name].matches("%#{name}%")
          ))
        )
      end

      def only_frontend_valid
        reflect(
          @query.where(
            place[:metadata].not_eq(nil).
            and(place_translation[:name].not_eq(nil)
            )
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

      def with_classification_alias_ids(ids = nil)
        manager = create_classification_alias_recursion(ids)
        # get everything including parents (or-clause)
        reflect(
          @query.where(place[:id].in(manager))
        )
      end

    private

    # joins

      def join_classification_alias2
        Arel::SelectManager.new.
          project(place[:id]).
          from(place).
          where(place[:template].eq(false)).
          join(place_translation).
            on(place[:id].eq(place_translation[:place_id])).
          where(place_translation[:locale].eq(quoted(@locale))).
          join(classification_place).
            on(place[:id].eq(classification_place[:place_id])).
          join(classification).
            on(classification_place[:classification_id].eq(classification[:id])).
          join(classification_group).
            on(classification[:id].eq(classification_group[:classification_id])).
          join(classification_alias).
            on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
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
        Place::Translation.arel_table
      end

      def classification_place
        ClassificationPlace.arel_table
      end

    end
  end
end
