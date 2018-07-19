# frozen_string_literal: true

module DataCycleCore
  module Filter
    class Search < QueryBuilder
      include DataCycleCore::Filter::Type::Event
      include DataCycleCore::Filter::Type::Place

      def initialize(locale = 'de', query = nil)
        @locale = locale
        @query = query || DataCycleCore::Search.where(search[:locale].eq(quoted(@locale)))
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

      def unique_by_column(column = :id)
        query = DataCycleCore::Search.select("DISTINCT ON (#{column}) id")

        reflect(@query.where(id: query))
      end

      def classification_alias_ids(ids = nil)
        return self if ids.blank?

        manager = create_classification_alias_recursion(ids)
        reflect(@query.where(search[:content_data_id].in(manager)))
      end

      def with_classification_alias_ids_without_recursion(ids = nil)
        return self if ids.blank?

        query2 = join_classification_alias2
        manager = query2.where(classification_alias[:id].in(ids))

        reflect(@query.where(search[:content_data_id].in(manager)))
      end

      def with_classification_aliases(tree_name, *aliases)
        reflect(
          @query.where(id: DataCycleCore::Search.joins(:classification_aliases).merge(
            DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(aliases).with_descendants
          ))
        )
      end

      def self.get_order_by_query_string(search)
        search_string = (search || '').split(' ').join('%')

        ActiveRecord::Base.send(:sanitize_sql_array,
                                ["boost * (
            8 * similarity(classification_string, :search_string) +
            4 * similarity(headline, :search_string) +
            2 * ts_rank_cd(words, plainto_tsquery('simple', :search),16) +
            1 * similarity(full_text, :search_string))
            DESC NULLS LAST,
            updated_at DESC", search_string: "%#{search_string}%", search: (search || '').squish])
      end

      private

      def join_classification_alias2
        Arel::SelectManager.new
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
      end

      def join_watch_list
        Arel::SelectManager.new
          .project(search[:content_data_id])
          .from(search)
          .join(watch_list_data_hash)
          .on(search[:content_data_id].eq(watch_list_data_hash[:hashable_id]).and(search[:content_data_type].eq(watch_list_data_hash[:hashable_type])))
      end

      def join_creative_work
        Arel::SelectManager.new
          .project(search[:content_data_id])
          .from(search)
          .join(creative_work)
          .on(search[:content_data_id].eq(creative_work[:id]).and(search[:content_data_type].eq(quoted('DataCycleCore::CreativeWork'))))
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

      def find_children(id)
        query = join_creative_work
        query.where(creative_work[:is_part_of].eq(id))
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

      def creative_work
        DataCycleCore::CreativeWork.arel_table
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
