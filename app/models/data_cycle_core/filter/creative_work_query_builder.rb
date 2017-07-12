module DataCycleCore
  module Filter
    class CreativeWorkQueryBuilder < QueryBuilder

      def initialize(locale = 'de', query = nil)
        @locale = locale
        @query = query || CreativeWork.unscoped.distinct.
          where(template: false).
          joins(
            creative_work.join(creative_work_translation).
            on(creative_work[:id].eq(creative_work_translation[:creative_work_id])).
            join_sources
          ).where(creative_work_translation[:locale].eq(quoted(@locale)))
      end

    # filters

      def fulltext_search(name)
        # include textsearch on classification_aliases.name
        query = join_classification_alias2
        manager = query.where(classification_alias[:name].matches("%#{name}%"))

        # textsearch on particular fields in creative_works
        query2 = join_creative_work_translation
        manager2 = query2.
          where(
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
            ).
            or(
            # trgm_match(
            #   coalesce(
            #     json_element(creative_work_translation[:content], quoted('headline')),
            #     coalesce(
            #       json_element(creative_work_translation[:content], quoted('caption')),
            #       json_element(creative_work_translation[:content], quoted('description'))
            #     )
            #   ),
            #   quoted(name)
            #   )
              coalesce(
                json_element(creative_work_translation[:content], quoted('headline')),
                coalesce(
                  json_element(creative_work_translation[:content], quoted('caption')),
                  json_element(creative_work_translation[:content], quoted('description'))
                )
              ).matches("%#{name}%")
            )
          )


        reflect(
          @query.where(
            creative_work[:id].in(manager2).or(
            creative_work[:id].in(manager))
          )
        )
      end

      def with_classification_alias_ids(ids = nil)
        manager = create_classification_alias_recursion(ids)
        # get everything including parents (or-clause)
        reflect(
          @query.where(creative_work[:id].in(manager))
        )
      end

    private

    # joins

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

      def join_classification_alias2
        Arel::SelectManager.new.
          project(creative_work[:id]).
          from(creative_work).
          where(creative_work[:template].eq(false)).
          join(creative_work_translation).
            on(creative_work[:id].eq(creative_work_translation[:creative_work_id])).
          where(creative_work_translation[:locale].eq(quoted(@locale))).
          join(classification_creative_work).
            on(creative_work[:id].eq(classification_creative_work[:creative_work_id])).
          join(classification).
            on(classification_creative_work[:classification_id].eq(classification[:id])).
          join(classification_group).
            on(classification[:id].eq(classification_group[:classification_id])).
          join(classification_alias).
            on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
      end

      def join_creative_work_translation
        Arel::SelectManager.new.
          project(creative_work[:id]).
          from(creative_work).
          where(creative_work[:template].eq(false)).
          join(creative_work_translation)
            .on(creative_work[:id].eq(creative_work_translation[:creative_work_id]))
          .where(creative_work_translation[:locale].eq(quoted(@locale)))
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
