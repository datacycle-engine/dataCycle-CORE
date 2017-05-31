module DataCycleCore
  module Filter
    class CreativeWorkQueryBuilder < QueryBuilder

      def initialize(language = "de", query = nil, classification_alias = false)
        @classification_alias = classification_alias
        @locale = language
        @query = query || CreativeWork.unscoped.distinct.
                            where(template: false).
                            joins(creative_work.join(creative_work_translation).
                            on(creative_work[:id].eq(creative_work_translation[:creative_work_id])).
                            join_sources
                          ).where(creative_work_translation[:locale].eq(quoted(@locale)))
      end

    # filters
      def with_highlight(name)
        reflect(
          @query.where(
            creative_work[:headline].matches("%#{name}%")
          )
        )
      end

      def fulltext_search(name)
        reflect(
          @query.where(
            tsmatch(
              to_tsvector(
                concatinate(
                  concatinate(
                    coalesce(json_element(creative_work_translation[:content], quoted('caption')), quoted(' ')),
                    coalesce(json_element(creative_work_translation[:content], quoted('description')),quoted(''))
                  ),
                  coalesce(json_element(creative_work_translation[:content], quoted('headline')), quoted(' ')),
                )
              ),
              to_tsquery(quoted(name))
            )
          )
        )
      end

    private

    # joins
      # def join_creative_work_translation
      #   @query.joins(creative_work.join(creative_work_translation)
      #     .on(creative_work[:id].eq(creative_work_translation[:creative_work_id]))
      #     .join_sources
      #   ).where(creative_work_translation[:locale].eq(quoted(@locale)))
      # end

      def join_classification_creative_work
        @query.joins(creative_work.join(classification_creative_work)
          .on(creative_work[:id].eq(classification_creative_work[:creative_work_id]))
          .join_sources
        )
      end


      def join_classification
        join_classification_creative_work.joins(classification_creative_work.join(classification)
          .on(classification_creative_work[:classification_id].eq(classification[:id]))
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
