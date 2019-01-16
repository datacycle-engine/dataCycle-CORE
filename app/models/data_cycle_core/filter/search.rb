# frozen_string_literal: true

module DataCycleCore
  module Filter
    class Search < QueryBuilder
      include DataCycleCore::Filter::Common::Configurable

      def initialize(locale = ['de'], query = nil)
        @locale = locale
        if locale.nil?
          @joined_search = false
          @query = query || DataCycleCore::Thing
        else
          @joined_search = true
          @query = query || DataCycleCore::Thing.joins(:searches).where(searches: { locale: @locale })
        end
      end

      def content_includes
        reflect(
          @query.includes(
            :translations,
            :watch_lists,
            :external_source,
            :parent,
            display_classification_aliases: :classification_alias_path
          )
        )
      end

      def fulltext_search(name)
        return self if name.blank?

        unless @joined_search
          @query = @query.joins(:searches)
          @joined_search = true
        end

        reflect(
          @query.where(
            search[:all_text].matches_all(name.split(' ').map { |item| "%#{item.strip}%" })
            .or(tsmatch(search[:words], tsquery(quoted(name.squish))))
          )
        )
      end

      # def only_frontend_valid
      #   reflect(
      #     @query.where(search[:schema_type].not_eq(quoted('Place')))
      #   )
      # end

      def in_validity_period(current_date = Time.zone.now)
        reflect(
          @query.where(in_range(thing[:validity_range], cast_tstz(current_date)))
        )
      end

      def external_source(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(thing[:external_source_id].in(ids))
        )
      end

      def creator(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(thing[:created_by].in(ids))
        )
      end

      def watch_list_id(id = nil)
        return self if id.blank?

        sub_query = Arel::SelectManager.new
          .project(thing[:id])
          .from(thing)
          .join(watch_list_data_hash)
          .on(thing[:id].eq(watch_list_data_hash[:hashable_id]))
          .where(watch_list_data_hash[:watch_list_id].eq(id))

        reflect(
          @query.where(thing[:id].in(sub_query))
        )
      end

      def part_of(id = nil)
        return self if id.blank?

        reflect(
          @query.where(thing[:is_part_of].eq(id))
        )
      end

      def relation(name = nil)
        return self if name.blank?

        sub_query = Arel::SelectManager.new
          .project(thing[:id])
          .from(thing)
          .join(content_content)
          .on(thing[:id].eq(content_content[:content_a_id]))
          .where(content_content[:relation_a].eq(name))

        reflect(
          @query.where(thing[:id].in(sub_query))
        )
      end

      def modified_since(date = Time.zone.now)
        reflect(
          @query.where(search[:updated_at].gteq(Time.zone.parse(date)))
        )
      end

      def created_since(date = Time.zone.now)
        reflect(
          @query.where(search[:created_at].gteq(Time.zone.parse(date)))
        )
      end

      def event_end_time(time)
        time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
        reflect(
          @query.where(thing[:start_date].lteq(Arel::Nodes.build_quoted(time.iso8601)))
        )
      end

      def event_from_time(time)
        time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
        reflect(
          @query.where(thing[:end_date].gteq(Arel::Nodes.build_quoted(time.iso8601)))
        )
      end

      def sort_by_proximity(date = Time.zone.now)
        reflect(
          @query.reorder(
            absolute_date_diff(thing[:end_date], Arel::Nodes.build_quoted(date.iso8601)),
            absolute_date_diff(thing[:start_date], Arel::Nodes.build_quoted(date.iso8601)),
            thing[:start_date]
          )
        )
      end

      def within_box(sw_lon, sw_lat, ne_lon, ne_lat)
        return self if sw_lon.blank? || sw_lat.blank? || ne_lon.blank? || ne_lat.blank?

        reflect(
          @query.where(contains(thing[:location], get_box(get_point(sw_lon, sw_lat), get_point(ne_lon, ne_lat))).eq('true'))
        )
      end

      def distinct_by_content_id(order_string = nil)
        return self if @locale.presence&.size == 1

        if @locale.nil?
          reflect(
            DataCycleCore::Thing
              .where(id: @query.select('DISTINCT ON (things.id) things.id').except(:order, :limit, :offset))
              .order(order_string)
          )
        else
          reflect(
            DataCycleCore::Thing.joins(:searches)
              .where(searches: { id: @query.select('DISTINCT ON (things.id) searches.id').except(:order, :limit, :offset) })
              .order(order_string)
          )
        end
      end

      def count_distinct
        return @query.except(:order, :limit, :offset).count unless @joined_search
        return @query.except(:order, :limit, :offset).count if @locale.presence&.size == 1
        @query.except(:order, :limit, :offset).count('DISTINCT things.id')
      end

      def classification_alias_ids(ids = nil)
        return self if ids.blank?

        reflect(@query.with_classification_alias_ids(ids))
      end

      def with_classification_alias_ids_without_recursion(ids = nil)
        return self if ids.blank?

        reflect(
          @query.where(
            thing[:id].in(
              join_classification_alias.where(classification_alias[:id].in(ids))
            )
          )
        )
      end

      def with_classification_aliases(tree_name, *aliases)
        sub_query = DataCycleCore::Thing
          .joins(:classification_aliases)
          .merge(
            DataCycleCore::ClassificationAlias
              .for_tree(tree_name)
              .with_name(aliases)
              .with_descendants
          )

        reflect(
          @query.where(id: sub_query)
        )
      end

      def self.get_order_by_query_string(search)
        return ActiveRecord::Base.send(:sanitize_sql_for_order, 'things.boost DESC, things.updated_at DESC') if search.blank?
        search_string = (search || '').split(' ').join('%')

        ActiveRecord::Base.send(
          :sanitize_sql_array,
          [
            "things.boost * (
              8 * similarity(searches.classification_string, :search_string) +
              4 * similarity(searches.headline, :search_string) +
              2 * ts_rank_cd(searches.words, plainto_tsquery('simple', :search),16) +
              1 * similarity(searches.full_text, :search_string))
              DESC NULLS LAST,
              things.updated_at DESC",
            search_string: "%#{search_string}%",
            search: (search || '').squish
          ]
        )
      end

      private

      def join_classification_alias
        Arel::SelectManager.new
          .project(thing[:id])
          .from(thing)
          .join(classification_content)
          .on(thing[:id].eq(classification_content[:content_data_id]))
          .join(classification)
          .on(classification_content[:classification_id].eq(classification[:id]))
          .join(classification_group)
          .on(classification[:id].eq(classification_group[:classification_id]))
          .join(classification_alias)
          .on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
          .where(
            classification[:deleted_at].eq(nil)
            .and(classification_group[:deleted_at].eq(nil))
            .and(classification_alias[:deleted_at].eq(nil))
          )
      end

      def classification_content
        DataCycleCore::ClassificationContent.arel_table
      end

      def classification
        Classification.arel_table
      end

      def classification_group
        ClassificationGroup.arel_table
      end

      def classification_alias
        ClassificationAlias.arel_table
      end

      def watch_list_data_hash
        DataCycleCore::WatchListDataHash.arel_table
      end

      def content_content
        DataCycleCore::ContentContent.arel_table
      end

      def search
        DataCycleCore::Search.arel_table
      end

      def thing
        DataCycleCore::Thing.arel_table
      end
    end
  end
end
