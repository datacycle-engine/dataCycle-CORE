# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Union
        UNION_FILTER_EXCEPTS = [
          :joins,
          :includes,
          :order,
          :reordering
        ].freeze

        def union_filter_ids(ids = nil)
          filter_query_sql = collection_ids_query(ids)

          return self if filter_query_sql.blank?

          reflect(@query.where(thing[:id].in(Arel.sql(filter_query_sql))))
        end

        def not_union_filter_ids(ids)
          filter_query_sql = collection_ids_query(ids)

          return self if filter_query_sql.blank?

          reflect(@query.where(thing[:id].not_in(Arel.sql(filter_query_sql))))
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

          wldh_alias = watch_list_data_hash.alias("wldh#{SecureRandom.hex(5)}")
          watch_lists = ids.all?(DataCycleCore::WatchList) ? ids : DataCycleCore::WatchList.where(id: ids).to_a

          subquery = DataCycleCore::WatchListDataHash.from(wldh_alias).except(*UNION_FILTER_EXCEPTS)
          subquery = subquery.select(wldh_alias[:thing_id])

          return subquery.where('1 = 0').to_sql if watch_lists.blank?

          subquery.where(wldh_alias[:watch_list_id].in(watch_lists.pluck(:id))).to_sql
        end

        def filter_ids_query(ids)
          return if ids.blank?

          filters = ids.all?(DataCycleCore::StoredFilter) ? ids : DataCycleCore::StoredFilter.where(id: ids)

          return DataCycleCore::Thing.where('1 = 0').arel.select(thing[:id]).to_sql if filters.blank?

          filters.map { |f|
            f.things(skip_ordering: true)
              .except(*UNION_FILTER_EXCEPTS)
              .select(thing[:id])
              .to_sql
          }.join(' UNION ')
        rescue SystemStackError
          raise DataCycleCore::Error::Filter::UnionFilterRecursionError
        end

        def collection_ids_query(ids)
          return if ids.blank?

          collections = DataCycleCore::Collection.where(id: ids)

          return DataCycleCore::Thing.where('1 = 0').arel.select(thing[:id]).to_sql if collections.blank?

          stored_filters = collections.filter { |f| f.is_a?(DataCycleCore::StoredFilter) }
          watch_lists = collections.filter { |f| f.is_a?(DataCycleCore::WatchList) }
          queries = []
          queries.push(watch_list_ids_query(watch_lists)) if watch_lists.present?
          queries.push(filter_ids_query(stored_filters)) if stored_filters.present?
          queries.join(' UNION ')
        end

        def union_filter(filters = [])
          filters = filters.map { |f| f.select(:id).except(*UNION_FILTER_EXCEPTS).to_sql }.compact_blank

          return self if filters.blank?

          reflect(
            @query.where(thing[:id].in(Arel.sql(filters.join(' UNION '))))
          )
        end
      end
    end
  end
end
