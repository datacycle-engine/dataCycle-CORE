module DataCycleCore
  module Filter
    class ImageQueryBuilder < CreativeWorkQueryBuilder

      def initialize(locale = 'de', query = nil)
        @locale = locale
        @query = query || CreativeWork.unscoped.select('distinct on (creative_works.id) *').
          where(template: false).includes(:translations)
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

            sql_date(json_path(creative_work[:metadata], quoted('{ validity_period, date_published }'))).eq(nil).
              or(
                sql_date(json_path(creative_work[:metadata], quoted('{ validity_period, date_published }'))).lteq(sql_date(quoted(current_date)))
            ).
            and(
              sql_date(json_path(creative_work[:metadata], quoted('{ validity_period, expires }'))).eq(nil).
              or(
                sql_date(json_path(creative_work[:metadata], quoted('{ validity_period, expires }'))).gteq(sql_date(quoted(current_date)))
              )
            )
          )
        )
      end

      def only_images
        reflect(
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
