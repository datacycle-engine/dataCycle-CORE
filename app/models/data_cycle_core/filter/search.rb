module DataCycleCore
  module Filter
    class Search < QueryBuilder

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

      def in_validity_period(current_date = Time.zone.now)
        reflect (
          @query.where(
            in_range(search[:validity_period], cast_tstz(current_date))
          )
        )
      end

      def by_watch_list_id(id = nil)
        manager = get_watch_list_items(id)

        reflect (
          @query.where(search[:content_data_id].in(manager))
        )
      end

      def modified_since(date = Time.zone.now)
        reflect (
          @query.where(
            search[:updated_at].gteq(DateTime.parse(date))
          )
        )
      end

      def created_since(date = Time.zone.now)
        reflect (
          @query.where(
            search[:created_at].gteq(DateTime.parse(date))
          )
        )
      end

      def with_classification_alias_ids(ids = nil)
        return self if ids.blank?

        manager = create_classification_alias_recursion(ids)
        reflect(@query.where(search[:content_data_id].in(manager)))
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

      def join_watch_list
        Arel::SelectManager.new.
        project(search[:content_data_id]).
        from(search).
        join(watch_list_data_hash).
          on(search[:content_data_id].eq(watch_list_data_hash[:hashable_id]).and(search[:content_data_type].eq(watch_list_data_hash[:hashable_type])))
      end

      def get_watch_list_items(id)
        query = join_watch_list
        query.where(watch_list_data_hash[:watch_list_id].eq(id))
      end

      def watch_list_data_hash
        DataCycleCore::WatchListDataHash.arel_table
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
