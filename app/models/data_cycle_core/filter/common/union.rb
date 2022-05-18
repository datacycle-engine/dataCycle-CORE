# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Union
        UNION_FILTER_EXCEPTS = [
<<<<<<< HEAD
=======
          :joins,
>>>>>>> old/develop
          :order,
          :reordering
        ].freeze

        def union_filter_ids(ids = nil)
          filter_queries = []

          [:filter_ids_query, :watch_list_ids_query].each do |filter|
            filter_query_sql_ids = send(filter, ids)
            next if filter_query_sql_ids.nil?

            union_query = DataCycleCore::StoredFilter.new(language: @locale).apply
            filter_queries.push(union_query.where(thing[:id].in(Arel.sql(filter_query_sql_ids.to_sql))))
          end

          union_filter(filter_queries)
        end

        def not_union_filter_ids(ids)
          filter_queries = []

          [:filter_ids_query, :watch_list_ids_query].each do |filter|
            filter_query_sql_ids = send(filter, ids)
            next if filter_query_sql_ids.nil?

            union_query = DataCycleCore::StoredFilter.new(language: @locale).apply
            filter_queries.push(union_query.where(thing[:id].not_in(Arel.sql(filter_query_sql_ids.to_sql))))
          end

          union_filter(filter_queries)
        end

        def content_ids(ids = nil)
          return self if ids.blank?

          if Array.wrap(ids).map(&:uuid?).inject(&:&)
            reflect(
              @query.where(thing[:id].in(ids))
            )
          else
            reflect(
              @query.where(
                DataCycleCore::Thing::Translation.where(
                  thing_translations[:slug].in(ids)
                    .and(thing[:id].eq(thing_translations[:thing_id]))
                ).arel.exists
              )
            )
          end
        end

        def not_content_ids(ids = nil)
          return self if ids.blank?
          if Array.wrap(ids).map(&:uuid?).inject(&:&)
            reflect(
              @query.where.not(thing[:id].in(ids))
            )
          else
            reflect(
              @query.where.not(
                DataCycleCore::Thing::Translation.where(
                  thing_translations[:slug].in(ids)
                    .and(thing[:id].eq(thing_translations[:thing_id]))
                ).arel.exists
              )
            )
          end
        end

        def filter_ids(ids = nil)
          filter_query_sql_ids = filter_ids_query(ids)
          return self if filter_query_sql_ids.nil?
          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_query_sql_ids.to_sql)))
          )
        end

        def not_filter_ids(ids = nil)
          filter_query_sql_ids = filter_ids_query(ids)
          return self if filter_query_sql_ids.nil?
          reflect(
            @query.where.not(thing[:id].in(Arel.sql(filter_query_sql_ids.to_sql)))
          )
        end

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
          return if ids.blank?

          filter_query_sql = nil
          DataCycleCore::WatchList.where(id: ids).find_each do |collection|
            if filter_query_sql.nil?
              filter_query_sql = collection.watch_list_data_hashes.select(:hashable_id).except(*UNION_FILTER_EXCEPTS)
            else
              filter_query_sql = filter_query_sql.or(collection.watch_list_data_hashes.select(:hashable_id).except(*UNION_FILTER_EXCEPTS))
            end
          end
          filter_query_sql
        end

        def filter_ids_query(ids)
          return if ids.blank?

          filter_query_sql = nil
          DataCycleCore::StoredFilter.where(id: ids).find_each do |filter|
            if filter_query_sql.nil?
              filter_query_sql = filter.apply.select(:id).except(*UNION_FILTER_EXCEPTS)
            else
              filter_query_sql = filter_query_sql.or(filter.apply.select(:id).except(*UNION_FILTER_EXCEPTS))
            end
          end
          filter_query_sql
        end

        def union_filter(filters = [])
          filter_query_sql = nil

          filters.each do |filter|
            if filter_query_sql.nil?
              filter_query_sql = filter.select(:id).except(*UNION_FILTER_EXCEPTS)
            else
              filter_query_sql = filter_query_sql.or(filter.select(:id).except(*UNION_FILTER_EXCEPTS))
            end
          end

          return self if filter_query_sql.nil?

          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_query_sql.to_sql)))
          )
        end
      end
    end
  end
end
