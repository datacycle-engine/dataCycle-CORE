module DataCycleCore
  module Filter
    class ImageQueryBuilder < CreativeWorkQueryBuilder

      def initialize(locale = 'de', query = nil)
        @locale = locale
        @query = query || CreativeWork.#unscoped.select('distinct creative_works.id').
          joins(:content_search_all, :translations).
          includes(:translations)


          # CreativeWork.unscoped.select('distinct on (creative_works.id) *').
          # where(template: false).includes(:translations, :content_search_all).joins(:content_search_all)
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
          @query.where(in_range(search[:validity_period], cast_tstz(current_date)))
        )
      end

      def only_images
        reflect(
          @query.where(search[:data_type].eq(quoted("Bild")))
        )
      end

      def fulltext_search(name)
        search_string = name.split(" ").join("%")
        order_string = "
          8 * word_similarity(searches.classification_string,'%#{search_string}%') +
          4 * word_similarity(searches.headline, '%#{search_string}%') +
          2 * ts_rank_cd(searches.words, plainto_tsquery('simple', '#{name.squish}'),16) +
          1 * word_similarity(searches.full_text, '%#{search_string}%')
          DESC NULLS LAST,
          searches.updated_at DESC"

        reflect(
          @query.where(
            search[:all_text].matches_all(name.split(' ').map{|item| "%#{item.strip}%"}).
            or(tsmatch(search[:words],to_tsquery(quoted(name.squish))))
          ).order(order_string)
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

      def search
        DataCycleCore::Search.arel_table
      end

    end
  end
end
