module DataCycleCore
  module Filter
    class Search < QueryBuilder

      def_delegators :@query, :includes, :to_a, :to_sql, :each, :map, :page #, :per, :total_pages, :current_page, :limit_value, :next_page, :prev_page, :first_page?, :last_page?, :out_of_range?
      TERMINAL_METHODS = [:count, :pluck,
        :first, :second, :third, :fourth, :fifth, :forty_two, :last]
      def_delegators :@query, *TERMINAL_METHODS

      def initialize(locale = 'de', query = nil)
        @locale = locale
        @query = query || DataCycleCore::Search.where(search[:locale].eq(quoted(@locale)))
      end

      def fulltext_search(name)
        reflect(
          @query.where(
            search[:all_text].matches_all(name.split(' ').map{|item| "%#{item.strip}%"}).
            or(tsmatch(search[:words],to_tsquery(quoted(name.squish))))
          )
        )
      end

      def only_frontend_valid
        reflect(
          @query.where(
            search[:content_data_type].not_eq(quoted('DataCycleCore::Place'))
          )
        )
      end

      def in_validity_period(current_date = Time.now)
        reflect (
          @query.where(
            in_range(search[:validity_period], cast_tstz(current_date))
          )
        )
      end

      def with_classification_alias_ids(ids = nil)
        manager = create_classification_alias_recursion(ids)
        # get everything including parents (or-clause)
        reflect(
          @query.where(search[:content_data_id].in(manager))
        )
      end

      def self.get_order_by_query_string(search)
        search_string = (search || '').split(' ').join('%')
        "boost * (
          8 * similarity(classification_string,'%#{search_string}%') +
          4 * similarity(headline, '%#{search_string}%') +
          2 * ts_rank_cd(words, plainto_tsquery('simple', '#{(search || '').squish}'),16) +
          1 * similarity(full_text, '%#{search_string}%'))
          DESC NULLS LAST,
          updated_at DESC"
      end

    private

      def join_classification_alias2
        Arel::SelectManager.new.
          project(search[:content_data_id]).
          from(search).
          join(classification_content).
            on(search[:content_data_id].eq(classification_content[:content_data_id])).
          join(classification).
            on(classification_content[:classification_id].eq(classification[:id])).
          join(classification_group).
            on(classification[:id].eq(classification_group[:classification_id])).
          join(classification_alias).
            on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
      end

      def search
        DataCycleCore::Search.arel_table
      end

      def classification_content
        DataCycleCore::ClassificationContent.arel_table
      end

    end
  end
end
