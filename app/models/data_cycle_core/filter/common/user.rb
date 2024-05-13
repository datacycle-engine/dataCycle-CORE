# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module User
        def user(ids = nil, type = nil)
          return self if type.blank?

          send(type, ids)
        end

        def not_user(ids = nil, type = nil)
          return self if type.blank?

          send("not_#{type}", ids)
        end

        def creator(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(thing[:created_by].in(ids))
          )
        end

        def not_creator(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where.not(thing[:created_by].in(ids))
          )
        end

        def last_editor(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(thing[:updated_by].in(ids))
          )
        end

        def not_last_editor(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where.not(thing[:updated_by].in(ids))
          )
        end

        def editor(ids = nil)
          return self if ids.blank?

          thing_query = DataCycleCore::Thing.where(updated_by: ids).select(:id).arel
          thing_history_query = DataCycleCore::Thing::History.where(updated_by: ids).select(:thing_id).arel

          reflect(
            @query.where(thing[:id].in(Arel::Nodes::UnionAll.new(thing_query, thing_history_query)))
          )
        end

        def not_editor(ids = nil)
          return self if ids.blank?

          thing_query = DataCycleCore::Thing.where(updated_by: ids).select(:id).arel
          thing_history_query = DataCycleCore::Thing::History.where(updated_by: ids).select(:thing_id).arel

          reflect(
            @query.where.not(thing[:id].in(Arel::Nodes::UnionAll.new(thing_query, thing_history_query)))
          )
        end

        def shared_with(ids = nil)
          return self if ids.blank?

          data_links = DataCycleCore::DataLink.by_receiver(ids).where(permissions: ['read', 'write']).valid

          filter_queries = []
          filter_queries.push(data_links.where(item_type: 'DataCycleCore::Thing').select(:item_id).except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS).to_sql)
          filter_queries.push(DataCycleCore::WatchListDataHash.where(watch_list_id: data_links.where(item_type: 'DataCycleCore::WatchList').select(:item_id), hashable_type: 'DataCycleCore::Thing').select(:hashable_id).except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS).to_sql)
          filter_queries.push(DataCycleCore::StoredFilter.where(id: data_links.where(item_type: 'DataCycleCore::StoredFilter').select(:item_id)).map { |f| f.apply(skip_ordering: true).select(:id).except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS).to_sql }.join(' UNION '))

          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_queries.compact_blank.join(' UNION '))))
          )
        end

        def shared_by_watch_list_shares(ids = nil)
          return self if ids.blank?

          combined_ids = Array.wrap(ids) + DataCycleCore::UserGroup.where(id: DataCycleCore::UserGroupUser.where(user_id: ids)).pluck(:id)

          raw_query = <<-SQL.squish
            SELECT 1
          	FROM watch_list_data_hashes
            INNER JOIN collection_shares ON collection_shares.collection_id = watch_list_data_hashes.watch_list_id
            WHERE watch_list_data_hashes.hashable_id = things.id
              AND watch_list_data_hashes.hashable_type = 'DataCycleCore::Thing'
              AND collection_shares.shareable_id IN (?)
          SQL

          reflect(
            @query.where(
              Arel::Nodes::Exists.new(
                Arel.sql(DataCycleCore::Thing.send(:sanitize_sql_for_conditions, [raw_query, combined_ids]))
              )
            )
          )
        end
      end
    end
  end
end
