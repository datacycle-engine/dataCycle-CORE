# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Union
        UNION_FILTER_EXCEPTS = [
          :joins,
          :order,
          :reordering
        ].freeze

        def union_filter_ids(ids = nil)
          filter_queries = []

          [:filter_ids_query, :watch_list_ids_query].each do |filter|
            filter_query_sql = send(filter, ids)
            filter_queries.push(filter_query_sql) if filter_query_sql.present?
          end

          union_filter(filter_queries)
        end

        def not_union_filter_ids(ids)
          filter_queries = []

          [:filter_ids_query, :watch_list_ids_query].each do |filter|
            filter_query_sql = send(filter, ids)
            filter_queries.push(filter_query_sql) if filter_query_sql.present?
          end

          not_union_filter(filter_queries)
        end

        def content_ids(ids = nil)
          return self if ids.blank?

          if Array.wrap(ids).all?(&:uuid?)
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
          if Array.wrap(ids).all?(&:uuid?)
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
          filter_query_sql = filter_ids_query(ids)
          return self if filter_query_sql.blank?
          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_query_sql)))
          )
        end

        def not_filter_ids(ids = nil)
          filter_query_sql = filter_ids_query(ids)
          return self if filter_query_sql.blank?
          reflect(
            @query.where.not(thing[:id].in(Arel.sql(filter_query_sql)))
          )
        end

        def watch_list_ids(ids = nil)
          filter_query_sql = watch_list_ids_query(ids)
          return self if filter_query_sql.blank?

          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_query_sql)))
          )
        end

        def not_watch_list_ids(ids = nil)
          filter_query_sql = watch_list_ids_query(ids)
          return self if filter_query_sql.blank?

          reflect(
            @query.where.not(thing[:id].in(Arel.sql(filter_query_sql)))
          )
        end

        def watch_list_ids_query(ids)
          return if ids.blank?

          DataCycleCore::WatchList.where(id: ids).watch_list_data_hashes.select(:hashable_id).except(*UNION_FILTER_EXCEPTS).to_sql
        end

        def filter_ids_query(ids)
          return if ids.blank?

          DataCycleCore::StoredFilter.where(id: ids).map { |f| f.apply(skip_ordering: true).select(:id).except(*UNION_FILTER_EXCEPTS).to_sql }.join(' UNION ')
        rescue SystemStackError
          raise DataCycleCore::Error::Filter::UnionFilterRecursionError
        end

        def union_filter(filters = [])
          filter_query_sql = filters.compact_blank.join(' UNION ')

          return self if filter_query_sql.nil?

          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_query_sql)))
          )
        end

        def not_union_filter(filters = [])
          filter_query_sql = filters.compact_blank.join(' UNION ')

          return self if filter_query_sql.nil?

          reflect(
            @query.where(thing[:id].not_in(Arel.sql(filter_query_sql)))
          )
        end
      end
    end
  end
end
