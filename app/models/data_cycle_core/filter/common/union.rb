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

          return self if filter_queries.blank?

          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_queries.join(' UNION ALL '))))
          )
        end

        def not_union_filter_ids(ids)
          filter_queries = []

          [:filter_ids_query, :watch_list_ids_query].each do |filter|
            filter_query_sql = send(filter, ids)
            filter_queries.push(filter_query_sql) if filter_query_sql.present?
          end

          return self if filter_queries.blank?

          reflect(
            @query.where(thing[:id].not_in(Arel.sql(filter_queries.join(' UNION ALL '))))
          )
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

          filters = DataCycleCore::StoredFilter.where(id: ids).index_by(&:id)

          Array.wrap(ids).map { |f| (filters[f]&.apply(skip_ordering: true) || DataCycleCore::Thing.where('1 = 0')).select(:id).except(*UNION_FILTER_EXCEPTS).to_sql }.join(' UNION ALL ')
        rescue SystemStackError
          raise DataCycleCore::Error::Filter::UnionFilterRecursionError
        end

        def union_filter(filters = [])
          filters = filters.map { |f| f.select(:id).except(*UNION_FILTER_EXCEPTS).to_sql }.compact_blank

          return self if filters.blank?

          reflect(
            @query.where(thing[:id].in(Arel.sql(filters.join(' UNION ALL '))))
          )
        end
      end
    end
  end
end
