module DataCycleCore
  module Filter
    class ImageQueryBuilder < CreativeWorkQueryBuilder

      def initialize(locale = 'de', query = nil)
        @locale = locale
        @query = query || CreativeWork.unscoped.distinct.
          where(template: false).
          joins(
            creative_work.join(creative_work_translation).
            on(creative_work[:id].eq(creative_work_translation[:creative_work_id])).
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

      def only_images
        # @query = join_classification_alias
        # manager = Arel::SelectManager.new.
        #   project(classification_alias[:id]).
        #   from(classification_alias).
        #   where(classification_alias[:name].eq(quoted('Bild'))).
        #   join(classification_tree).
        #     on(classification_tree[:classification_alias_id].eq(classification_alias[:id])).
        #   join(classification_tree_label).
        #     on(classification_tree[:classification_tree_label_id].eq(classification_tree_label[:id])).
        #   where(classification_tree_label[:name].eq(quoted('Inhaltstypen')))

        reflect(
          #@query.where(classification_alias[:id].in(manager))
          @query.where(json_path(creative_work[:metadata], quoted('{  validation, name }')).eq(quoted("Bild")))

        )
      end

    private

    # joins

      def join_creative_work_translation
        Arel::SelectManager.new.
          project(creative_work[:id]).
          from(creative_work).
          where(creative_work[:template].eq(false)).
          join(creative_work_translation)
            .on(creative_work[:id].eq(creative_work_translation[:creative_work_id]))
      end

    # define Arel-tables

      def classification_tree_label
        ClassificationTreeLabel.arel_table
      end

    end
  end
end
