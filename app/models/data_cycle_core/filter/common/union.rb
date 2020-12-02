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
          return self if filter_query_sql_ids.nil?
          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_query_sql_ids.to_sql)))
          )
        end
        alias union_filter_ids filter_ids

        def not_filter_ids(ids = nil)
          filter_query_sql_ids = filter_ids_query(ids)
          return self if filter_query_sql_ids.nil?
          reflect(
            @query.where.not(thing[:id].in(Arel.sql(filter_query_sql_ids.to_sql)))
          )
        end
        alias not_union_filter_ids not_filter_ids

        def watch_list_ids(ids = nil)
          filter_query_sql_ids = watch_list_ids_query(ids)
          return self if filter_query_sql_ids.nil?

          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_query_sql_ids.to_sql)))
          )
        end

        def not_watch_list_ids(ids = nil)
          filter_query_sql_ids = watch_list_ids_query(ids)
          return self if filter_query_sql_ids.nil?

          reflect(
            @query.where.not(thing[:id].in(Arel.sql(filter_query_sql_ids.to_sql)))
          )
        end

        def watch_list_ids_query(ids)
          return nil if ids.blank?

          filter_query_sql = nil
          ids.each do |id|
            watch_list = DataCycleCore::WatchList.find_by(id: id)
            next if watch_list.blank?
            if filter_query_sql.nil?
              filter_query_sql = watch_list.watch_list_data_hashes.select(:hashable_id).except(:order)
            else
              filter_query_sql = filter_query_sql.or(watch_list.watch_list_data_hashes.select(:hashable_id).except(:order))
            end
          end
          filter_query_sql
        end

        def filter_ids_query(ids)
          return nil if ids.blank?
          filter_query_sql = nil
          ids.each do |filter|
            stored_filter = DataCycleCore::StoredFilter.find_by(id: filter)
            next if stored_filter.blank?
            if filter_query_sql.nil?
              filter_query_sql = stored_filter.apply.select(:id).except(:order)
            else
              filter_query_sql = filter_query_sql.or(stored_filter.apply.select(:id).except(:order))
            end
          end
          filter_query_sql
        end

        def union_filter(filters = [])
          filter_query_sql = nil
          filters.each do |filter|
            if filter_query_sql.nil?
              filter_query_sql = filter.select(:id).except(:order)
            else
              filter_query_sql = filter_query_sql.or(filter.select(:id).except(:order))
            end
          end
          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_query_sql.to_sql)))
          )
        end
      end
    end
  end
end
