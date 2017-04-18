module DataCycleCore
  module Filter
    class PlaceQueryBuilder
      extend Forwardable

      attr_reader :query,:uuid
      def_delegator :@query, :to_sql

      def initialize(uuid, query = nil)
        @uuid = uuid
        @query = query || place.project(Arel.star).where(place[:external_source_id].eq(uuid))
      end

      def execute
        Place.find_by_sql(@query.to_sql)
      end

      def count
        Place.find_by_sql(@query.to_sql).count
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
      def with_name_locale(name, locale=I18n.locale.to_s)
        reflect(
          join_place_translation.where(
            place_translation[:locale].eq(locale)
            .and(place_translation[:name].matches("%#{name}%"))
          )
        )
      end

      def with_classification_id(id)
        reflect(
          join_classification_place.where(
            classification_place[:external_source_id].eq(@uuid)
            .and(classification_place[:classification_id].eq(id))
          )
        )
      end

      def with_classification(name)
        reflect(
          join_classification.where(
            classification_place[:external_source_id].eq(@uuid)
            .and(classification[:name].matches("%#{name}%"))
          )
        )
      end

      def with_classification_alias(name)
        reflect(
          join_classification_alias.where(
            classification_alias[:name].matches("%#{name}%")
          )
        )
      end

      def with_classification_alias_ids(ids = nil)
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
        classification_ids = result.map{|item| item["top_id"]} # including children
        reflect(
          join_classification_alias.where(
            classification_alias[:id].in(classification_ids)
          )
        )
      end

    private

    # joins
      def join_place_translation
        @query.join(place_translation)
          .on(place[:id].eq(place_translation[:place_id]))
      end

      def join_classification_place
        @query.join(classification_place)
          .on(place[:id].eq(classification_place[:place_id]))
      end

      def join_classification
        join_classification_place.join(classification)
          .on(classification_place[:classification_id].eq(classification[:id]))
      end

      def join_classification_group
        join_classification.join(classification_group)
          .on(classification_group[:classification_id].eq(classification[:id]))
      end

      def join_classification_alias
        join_classification_group.join(classification_alias)
          .on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
      end

    # chain method for Builder pattern
      def reflect(query)
        self.class.new(@uuid, query)
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
