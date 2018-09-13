# frozen_string_literal: true

module DataCycleCore
  module Filter
    class Search < QueryBuilder
      include DataCycleCore::Filter::Type::Event
      include DataCycleCore::Filter::Type::Place
      include DataCycleCore::Filter::Type::CreativeWork
      include DataCycleCore::Filter::Common::Configurable

      def initialize(locale = ['de'], query = nil)
        @locale = locale
        @query = query || DataCycleCore::Search.where(locale: @locale)
      end

      def content_includes
        includes(
          content_data: [
            :display_classification_aliases,
            :translations,
            :watch_lists,
            :external_source
          ]
        )
      end

      def fulltext_search(name)
        reflect(
          @query.where(
            search[:all_text].matches_all(name.split(' ').map { |item| "%#{item.strip}%" })
              .or(tsmatch(search[:words], tsquery(quoted(name.squish))))
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
        reflect(
          @query.where(
            in_range(search[:validity_period], cast_tstz(current_date))
          )
        )
      end

      def external_source(ids = nil)
        return self if ids.blank?
        query = Arel::SelectManager.new
          .project(content_meta_item[:id])
          .from(content_meta_item)
          .where(content_meta_item[:external_source_id].in(ids))

        reflect(@query.where(search[:content_data_id].in(query)))
      end

      def creator(ids = nil)
        return self if ids.blank?

        joined_creators = content_content.alias('joined_creators')
        join_query = search.join(joined_creators)
          .on(search[:content_data_id].eq(joined_creators[:content_a_id]).and(search[:content_data_type].eq(quoted(joined_creators[:content_a_type]))).and(joined_creators[:relation_a].eq('creator'))).join_sources

        @query = @query.joins(join_query)
          .where(joined_creators[:content_b_id].in(ids))

        reflect(@query)
      end

      def watch_list_id(id = nil)
        manager = get_watch_list_items(id)

        reflect(
          @query.where(search[:content_data_id].in(manager))
        )
      end

      def part_of(id = nil)
        manager = find_children(id)

        reflect(
          @query.where(search[:content_data_id].in(manager))
        )
      end

      def relation(name = nil)
        manager = find_relation(name)

        reflect(
          @query.where(search[:content_data_id].in(manager))
        )
      end

      def modified_since(date = Time.zone.now)
        reflect(
          @query.where(
            search[:updated_at].gteq(Time.zone.parse(date))
          )
        )
      end

      def created_since(date = Time.zone.now)
        reflect(
          @query.where(
            search[:created_at].gteq(Time.zone.parse(date))
          )
        )
      end

      def distinct_by_content_id(order_string = nil)
        return self if @locale.presence&.size == 1

        if order_string.is_a?(String)
          order_expression = "#{@query.table_name}.content_data_id, #{order_string}"
        elsif order_string.is_a?(Hash)
          order_expression = { content_data_id: :asc }.merge(order_string)
        else
          order_expression = { content_data_id: :asc }
        end

        order_expression = ActiveRecord::Base.send(:sanitize_sql_for_order, order_expression)

        query = @query.model
          .select(:content_data_id, :content_data_type)
          .order(order_string)

        query2 = select("DISTINCT ON (#{@query.table_name}.content_data_id) #{@query.table_name}.id")
          .reorder(order_expression)

        reflect(query.where(id: query2))
      end

      def count_distinct
        if @locale.presence&.size == 1
          subquery = select(:id)
        else
          subquery = select("DISTINCT ON (#{@query.table_name}.content_data_id) #{@query.table_name}.id")
        end

        @query.model.from(subquery.except(:order, :limit, :offset), :count_query).count
      end

      def classification_alias_ids(ids = nil)
        return self if ids.blank?

        # manager = create_classification_alias_recursion(ids)
        # reflect(@query.where(search[:content_data_id].in(manager)))

        reflect(@query.with_classification_aliases(ids))
      end

      def with_classification_alias_ids_without_recursion(ids = nil)
        return self if ids.blank?

        query2 = join_classification_alias2
        manager = query2.where(classification_alias[:id].in(ids))

        reflect(@query.where(search[:content_data_id].in(manager)))
      end

      def with_classification_aliases(tree_name, *aliases)
        query2 = DataCycleCore::Search
          .joins(:classification_aliases)
          .merge(
            DataCycleCore::ClassificationAlias
              .for_tree(tree_name)
              .with_name(aliases)
              .with_descendants
          )
        query2 = query2.where(search[:locale].in(@locale)) if @locale.present?

        reflect(
          @query.where(id: query2)
        )
      end

      def self.get_order_by_query_string(search, table_name = 'searches')
        return ActiveRecord::Base.send(:sanitize_sql_for_order, { boost: :desc, updated_at: :desc }) if search.blank?

        search_string = (search || '').split(' ').join('%')

        ActiveRecord::Base.send(:sanitize_sql_array,
                                ["boost * (
            8 * similarity(#{table_name}.classification_string, :search_string) +
            4 * similarity(#{table_name}.headline, :search_string) +
            2 * ts_rank_cd(#{table_name}.words, plainto_tsquery('simple', :search),16) +
            1 * similarity(#{table_name}.full_text, :search_string))
            DESC NULLS LAST,
            #{table_name}.updated_at DESC", search_string: "%#{search_string}%", search: (search || '').squish])
      end

      private

      def join_classification_alias2
        join_manager = Arel::SelectManager.new
          .project(search[:content_data_id])
          .from(search)
          .join(classification_content)
          .on(search[:content_data_id].eq(classification_content[:content_data_id]))
          .join(classification)
          .on(classification_content[:classification_id].eq(classification[:id]))
          .join(classification_group)
          .on(classification[:id].eq(classification_group[:classification_id]))
          .join(classification_alias)
          .on(classification_group[:classification_alias_id].eq(classification_alias[:id]))

        if @locale.present?
          return join_manager.where(
            search[:locale].in(@locale)
            .and(classification[:deleted_at].eq(nil))
            .and(classification_group[:deleted_at].eq(nil))
            .and(classification_alias[:deleted_at].eq(nil))
          )
        else
          return join_manager.where(
            classification[:deleted_at].eq(nil)
            .and(classification_group[:deleted_at].eq(nil))
            .and(classification_alias[:deleted_at].eq(nil))
          )
        end
      end

      def join_watch_list
        Arel::SelectManager.new
          .project(search[:content_data_id])
          .from(search)
          .join(watch_list_data_hash)
          .on(search[:content_data_id].eq(watch_list_data_hash[:hashable_id]).and(search[:content_data_type].eq(watch_list_data_hash[:hashable_type])))
      end

      def join_content_relation
        Arel::SelectManager.new
          .project(search[:content_data_id])
          .from(search)
          .join(content_content)
          .on(search[:content_data_id].eq(content_content[:content_a_id]).and(search[:content_data_type].eq(quoted(content_content[:content_a_type]))))
      end

      def get_watch_list_items(id)
        query = join_watch_list
        query.where(watch_list_data_hash[:watch_list_id].eq(id))
      end

      def find_relation(name)
        query = join_content_relation
        query.where(content_content[:relation_a].eq(name))
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

      def content_meta_item
        DataCycleCore::ContentMetaItem.arel_table
      end

      def content_content
        DataCycleCore::ContentContent.arel_table
      end
    end
  end
end
