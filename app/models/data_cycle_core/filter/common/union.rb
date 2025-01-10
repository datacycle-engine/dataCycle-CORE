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

          case DataCycleCore.union_filter_strategy
          when 'exists'
            reflect(@query.where("EXISTS (#{Arel.sql(filter_query_sql)})"))
          else
            reflect(@query.where(thing_alias[:id].in(Arel.sql(filter_query_sql))))
          end
        end

        def not_union_filter_ids(ids)
          filter_query_sql = collection_ids_query(ids)

          return self if filter_query_sql.blank?

          case DataCycleCore.union_filter_strategy
          when 'exists'
            reflect(@query.where.not("EXISTS (#{Arel.sql(filter_query_sql)})"))
          else
            reflect(@query.where(thing_alias[:id].not_in(Arel.sql(filter_query_sql))))
          end
        end

        def content_ids(ids = nil)
          return self if ids.blank?

          if Array.wrap(ids).all?(&:uuid?)
            reflect(
              @query.where(thing_alias[:id].in(ids))
            )
          else
            reflect(
              @query.where(
                DataCycleCore::Thing::Translation.where(
                  thing_translations[:slug].in(ids)
                    .and(thing_alias[:id].eq(thing_translations[:thing_id]))
                ).arel.exists
              )
            )
          end
        end

        def not_content_ids(ids = nil)
          return self if ids.blank?

          if Array.wrap(ids).all?(&:uuid?)
            reflect(
              @query.where.not(thing_alias[:id].in(ids))
            )
          else
            reflect(
              @query.where.not(
                DataCycleCore::Thing::Translation.where(
                  thing_translations[:slug].in(ids)
                    .and(thing_alias[:id].eq(thing_translations[:thing_id]))
                ).arel.exists
              )
            )
          end
        end

        def filter_ids(ids = nil)
          filter_query_sql = filter_ids_query(ids)
          return self if filter_query_sql.blank?

          reflect(
            @query.where(thing_alias[:id].in(Arel.sql(filter_query_sql)))
          )
        end

        def not_filter_ids(ids = nil)
          filter_query_sql = filter_ids_query(ids)
          return self if filter_query_sql.blank?

          reflect(
            @query.where.not(thing_alias[:id].in(Arel.sql(filter_query_sql)))
          )
        end

        def watch_list_ids(ids = nil)
          filter_query_sql = watch_list_ids_query(ids)
          return self if filter_query_sql.blank?

          reflect(
            @query.where(thing_alias[:id].in(Arel.sql(filter_query_sql)))
          )
        end

        def not_watch_list_ids(ids = nil)
          filter_query_sql = watch_list_ids_query(ids)
          return self if filter_query_sql.blank?

          reflect(
            @query.where.not(thing_alias[:id].in(Arel.sql(filter_query_sql)))
          )
        end

        def watch_list_ids_query(ids)
          return if ids.blank?

          wldh_alias = watch_list_data_hash.alias("wldh_#{SecureRandom.hex(5)}")
          watch_lists = ids.all?(DataCycleCore::WatchList) ? ids : DataCycleCore::WatchList.where(id: ids).to_a

          subquery = DataCycleCore::WatchListDataHash.from(wldh_alias).except(*UNION_FILTER_EXCEPTS)

          case DataCycleCore.union_filter_strategy
          when 'exists'
            subquery = subquery.select(1).where(wldh_alias[:thing_id].eq(thing_alias[:id]))
          else
            subquery = subquery.select(wldh_alias[:thing_id])
          end

          return subquery.where('1 = 0').to_sql if watch_lists.blank?

          subquery.where(wldh_alias[:watch_list_id].in(ids.pluck(:id))).to_sql
        end

        def filter_ids_query(ids)
          return if ids.blank?

          filters = ids.all?(DataCycleCore::StoredFilter) ? ids : DataCycleCore::StoredFilter.where(id: ids)

          if filters.blank?
            t_alias = generate_thing_alias
            return DataCycleCore::Thing.where('1 = 0').arel.from(t_alias).select(1).where(t_alias[:id].eq(thing_alias[:id])).to_sql
          end

          filters.map { |f|
            t_alias = generate_thing_alias

            subquery = f.things(skip_ordering: true, thing_alias: t_alias).except(*UNION_FILTER_EXCEPTS)

            case DataCycleCore.union_filter_strategy
            when 'exists'
              subquery = subquery.select(1).where(t_alias[:id].eq(thing_alias[:id]))
            else
              subquery = subquery.select(t_alias[:id])
            end

            subquery.to_sql
          }.join(' UNION ALL ')
        rescue SystemStackError
          raise DataCycleCore::Error::Filter::UnionFilterRecursionError
        end

        def collection_ids_query(ids)
          return if ids.blank?

          collections = DataCycleCore::Collection.where(id: ids)

          if collections.blank?
            t_alias = generate_thing_alias
            return DataCycleCore::Thing.where('1 = 0').arel.from(t_alias).select(1).where(t_alias[:id].eq(thing_alias[:id])).to_sql
          end

          stored_filters = collections.filter { |f| f.is_a?(DataCycleCore::StoredFilter) }
          watch_lists = collections.filter { |f| f.is_a?(DataCycleCore::WatchList) }
          queries = []
          queries.push(watch_list_ids_query(watch_lists)) if watch_lists.present?
          queries.push(filter_ids_query(stored_filters)) if stored_filters.present?
          queries.join(' UNION ALL ')
        end

        def union_filter(filters = [])
          raise 'test'
          binding.pry
          filters = filters.map { |f| f.select(:id).except(*UNION_FILTER_EXCEPTS).to_sql }.compact_blank

          return self if filters.blank?

          reflect(
            @query.where(thing_alias[:id].in(Arel.sql(filters.join(' UNION ALL '))))
          )
        end
      end
    end
  end
end
