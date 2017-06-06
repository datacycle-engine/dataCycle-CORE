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
        # ids = ['0543d553-3c2d-4f49-bf19-5d2e59a15d82', '5ae2c5f2-1534-4800-b1fb-216b789cf9cb']
        # unless @classification_alias # see if joins are necessary
        #   @query = join_classification_alias
        #   @classification_alias = true
        # end

        children = Arel::Table.new(:children)
        recursive_term = Arel::SelectManager.new
          .from(classification_tree)
          .project(Arel.star)
          .where(classification_tree[:parent_classification_alias_id].in(ids))
        non_recursive_term = Arel::SelectManager.new
          .project(classification_tree[Arel.star])
          .from(classification_tree).join(children)
          .on(classification_tree[:parent_classification_alias_id].eq(children[:classification_alias_id]))
        union = recursive_term.union(:all, non_recursive_term)
        cte_as_statement = Arel::Nodes::As.new(children, union)
        select_manager = Arel::SelectManager.new(ActiveRecord::Base).freeze
        manager = select_manager
          .with(:recursive, cte_as_statement)
          .from(children)
          .project(children[:classification_alias_id])

        query2 = join_classification_alias2
        manager2 = query2.where(classification_alias[:id].in(manager)
        .or(classification_alias[:id].in(ids)))


        # get everything including parents (or-clause)
        reflect(
          @query.where(creative_work[:id].in(manager2))
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

      def classification_creative_work2
        classification_creative_work.alias("classification_creative_work2")
      end

      def classification2
        classification.alias("classification2")
      end

      def classification_group2
        classification_group.alias("classification_group2")
      end

      def classification_alias2
        classification_alias.alias("classification_alias2")
      end

    end
  end
end
