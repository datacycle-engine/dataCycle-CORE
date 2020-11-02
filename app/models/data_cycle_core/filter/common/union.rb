# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Union
        def content_ids(ids = nil)
          return self if ids.blank?
          reflect(
            @query.where(thing[:id].in(ids))
          )
        end

        def not_content_ids(ids = nil)
          return self if ids.blank?
          reflect(
            @query.where.not(thing[:id].in(ids))
          )
        end

        def filter_ids(ids = nil)
          filter_query_sql_ids = filter_ids_query(ids)
          return self if filter_query_sql_ids.blank?

          reflect(
            @query.where(thing[:id].in(filter_query_sql_ids.uniq))
          )
        end
        alias union_filter_ids filter_ids

        def not_filter_ids(ids = nil)
          filter_query_sql_ids = filter_ids_query(ids)
          return self if filter_query_sql_ids.blank?

          reflect(
            @query.where.not(thing[:id].in(filter_query_sql_ids.uniq))
          )
        end
        alias not_union_filter_ids not_filter_ids

        def watch_list_ids(ids = nil)
          filter_query_sql_ids = watch_list_ids_query(ids)
          return self if filter_query_sql_ids.blank?

          reflect(
            @query.where(thing[:id].in(filter_query_sql_ids.uniq))
          )
        end

        def not_watch_list_ids(ids = nil)
          filter_query_sql_ids = watch_list_ids_query(ids)
          return self if filter_query_sql_ids.blank?

          reflect(
            @query.where.not(thing[:id].in(filter_query_sql_ids.uniq))
          )
        end

        def watch_list_ids_query(ids)
          return if ids.blank?

          filter_query_sql_ids = []
          ids.each do |id|
            watch_list = DataCycleCore::WatchList.find(id)
            next if watch_list.blank?
            filter_query_sql_ids += watch_list.watch_list_data_hashes.pluck(:hashable_id)
          end
          filter_query_sql_ids
        end

        def filter_ids_query(ids)
          return if ids.blank?
          filter_query_sql_ids = []
          ids.each do |filter|
            stored_filter = DataCycleCore::StoredFilter.find(filter)
            next if stored_filter.blank?
            filter_query_sql_ids += stored_filter.apply.pluck(:id)
          end
          filter_query_sql_ids
        end

        def union_filter(filters = [])
          filter_query_sql_ids = []
          filters.each do |filter|
            filter_query_sql_ids += filter.pluck(:id)
          end

          reflect(
            @query.where(thing[:id].in(filter_query_sql_ids.uniq))
          )
        end

        # def apply_or_filters(filters = [])
        #   filter_query_sql = []
        #   filter_query_sql_ids = []
        #   filters.each do |filter|
        #     filter_query_sql << Arel.sql(filter.select(:id).except(:order).to_sql)
        #     # filter_query_sql_ids += filter.pluck(:id)
        #   end
        #
        #   # reflect(
        #   #   @query.where(thing[:id].in(filter_query_sql_ids.uniq))
        #   # )
        #   if filter_query_sql.size > 1
        #     reflect(
        #       @query.where(thing[:id].in(Arel::Nodes::UnionAll.new(*filter_query_sql)))
        #     )
        #   else
        #     reflect(
        #       @query.where(thing[:id].in(filter_query_sql))
        #     )
        #   end
        # end
      end
    end
  end
end
