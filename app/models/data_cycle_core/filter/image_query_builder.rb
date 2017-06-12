module DataCycleCore
  module Filter
    class ImageQueryBuilder < QueryBuilder

      def initialize(query = nil, language = nil)
        @language = language
        @query = query
        @query ||= CreativeWork.unscoped.distinct.
          where(template: false).
          joins(creative_work.
            join(creative_work_translation).
            on(creative_work[:id].
            eq(creative_work_translation[:creative_work_id])).
            join_sources
          )
      end

    # filters

      def with_locale(language)
        reflect(
          @query.where(
            creative_work_translation[:locale].eq(quoted(language.to_s))
          )
        )
      end

      def in_validity_period(current_date = Time.now)
        reflect (
          @query.where(
            # Arel::Nodes::Between.new(
            #   sql_date(quoted(current_date)),
            #   Arel::Nodes::And.new(
            #     [
            #       sql_date(json_path(creative_work[:metadata], quoted('{ validityPeriod, datePublished }'))),
            #       sql_date(json_path(creative_work[:metadata], quoted('{ validityPeriod, expires }')))
            #     ]
            #   )
            # )
            sql_date(json_path(creative_work[:metadata], quoted('{ validityPeriod, datePublished }'))).eq(nil).
              or(
                sql_date(json_path(creative_work[:metadata], quoted('{ validityPeriod, datePublished }'))).lteq(sql_date(quoted(current_date)))
            ).
            and(
              sql_date(json_path(creative_work[:metadata], quoted('{ validityPeriod, expires }'))).eq(nil).
              or(
                sql_date(json_path(creative_work[:metadata], quoted('{ validityPeriod, expires }'))).gteq(sql_date(quoted(current_date)))
              )
            )
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
                    coalesce(json_element(creative_work_translation[:content], quoted('caption')), quoted('')),
                    coalesce(json_element(creative_work_translation[:content], quoted('description')),quoted(''))
                  ),
                  coalesce(json_element(creative_work_translation[:content], quoted('headline')), quoted('')),
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

      def only_images

        @query = join_classification_alias
        manager = Arel::SelectManager.new.
          project(classification_alias[:id]).
          from(classification_alias).
          where(classification_alias[:name].eq(quoted('Bild'))).
          join(classification_tree).
            on(classification_tree[:classification_alias_id].eq(classification_alias[:id])).
          join(classification_tree_label).
            on(classification_tree[:classification_tree_label_id].eq(classification_tree_label[:id])).
          where(classification_tree_label[:name].eq(quoted('Inhaltstypen')))

        reflect(
          @query.where(classification_alias[:id].in(manager))
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

      def classification_tree_label
        ClassificationTreeLabel.arel_table
      end

      def reflect(query)
        self.class.new(query, @language)
      end

    end
  end
end
