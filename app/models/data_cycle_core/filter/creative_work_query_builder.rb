module DataCycleCore
  module Filter
    class CreativeWorkQueryBuilder < QueryBuilder

      def initialize(uuid, query = nil, translation = false, classification_alias = false)
        @translation = translation
        @classification_alias = classification_alias
        @uuid = uuid
        @query = query || CreativeWork.unscoped.distinct
      end

    # filters
      def with_highlight(name)
        unless @translation # see if joins are necessary
          @query = join_creative_work_translation
          @translation = true
        end
        reflect(
          @query.where(
            creative_work[:headline].matches("%#{name}%")
          )
        )
      end

    private

    # joins
      def join_creative_work_translation
        @query.joins(creative_work.join(creative_work_translation)
          .on(creative_work[:id].eq(creative_work_translation[:creative_work_id]))
          .join_sources
        )
      end

      def join_classification_creative_work
        @query.joins(creative_work.join(classification_creative_work)
          .on(creative_work[:id].eq(classification_creative_work[:creative_work_id]))
          .join_sources
        )
      end

      def join_classification_alias
        join_classification_creative_work.joins(classification_creative_work.join(classification_alias)
          .on(classification_creative_work[:classification_alias_id].eq(classification_alias[:id]))
          .join_sources
        )
      end

    # define Arel-tables
      def creative_work
        CreativeWork.arel_table
      end

      def creative_work_translation
        CreativeWorkTranslation.arel_table
      end

      def classification_creative_work
        ClassificationCreativeWork.arel_table
      end

    end
  end
end
