# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module User
        KEY_MAPPING = {
          'creator' => :created_by,
          'last_editor' => :updated_by
        }.freeze

        def user(ids = nil, type = nil)
          return self if type.blank?

          send(type, ids)
        end

        def exists_user(_ids = nil, type = nil)
          return self if type.blank?

          key = KEY_MAPPING[type.to_s]&.to_sym
          return exists_editor if key.blank?

          reflect(
            @query.where(thing[key].not_eq(nil))
          )
        end

        def not_exists_user(_ids = nil, type = nil)
          return self if type.blank?

          key = KEY_MAPPING[type.to_s]&.to_sym
          return not_exists_editor if key.blank?

          reflect(
            @query.where(thing[key].eq(nil))
          )
        end

        def like_user(value = nil, type = nil)
          return self if value&.dig('text').blank? || type.blank?

          key = KEY_MAPPING[type.to_s]&.to_sym
          return like_editor(value) if key.blank?

          subquery = DataCycleCore::User
            .where('users.email ILIKE ?', "%#{value['text']}%")
            .where(thing[key].eq(user_table[:id]))
            .select(1)
            .arel
            .exists

          reflect(@query.where(subquery))
        end

        def not_like_user(value = nil, type = nil)
          return self if value&.dig('text').blank? || type.blank?

          key = KEY_MAPPING[type.to_s]&.to_sym
          return not_like_editor(value) if key.blank?

          subquery = DataCycleCore::User
            .where('users.email ILIKE ?', "%#{value['text']}%")
            .where(thing[key].eq(user_table[:id]))
            .select(1)
            .arel
            .exists

          reflect(@query.where.not(subquery))
        end

        def not_user(ids = nil, type = nil)
          return self if type.blank?

          send(:"not_#{type}", ids)
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

          t_alias = generate_thing_alias
          thing_query = thing
            .project(1)
            .from(t_alias)
            .where(t_alias[:id].eq(thing[:id]))
            .where(t_alias[:updated_by].in(ids))
          thing_history_query = thing_history_table
            .project(1)
            .where(thing_history_table[:thing_id].eq(thing[:id]))
            .where(thing_history_table[:updated_by].in(ids))

          reflect(
            @query.where(
              Arel::Nodes::Exists.new(
                Arel::Nodes::UnionAll.new(thing_query, thing_history_query)
              )
            )
          )
        end

        def not_editor(ids = nil)
          return self if ids.blank?

          t_alias = generate_thing_alias
          thing_query = thing
            .project(1)
            .from(t_alias)
            .where(t_alias[:id].eq(thing[:id]))
            .where(t_alias[:updated_by].in(ids))
          thing_history_query = thing_history_table
            .project(1)
            .where(thing_history_table[:thing_id].eq(thing[:id]))
            .where(thing_history_table[:updated_by].in(ids))

          reflect(
            @query.where.not(
              Arel::Nodes::Exists.new(
                Arel::Nodes::UnionAll.new(thing_query, thing_history_query)
              )
            )
          )
        end

        def exists_editor
          t_alias = generate_thing_alias
          thing_query = thing
            .project(1)
            .from(t_alias)
            .where(t_alias[:id].eq(thing[:id]))
            .where(t_alias[:updated_by].not_eq(nil))
          thing_history_query = thing_history_table
            .project(1)
            .where(thing_history_table[:thing_id].eq(thing[:id]))
            .where(thing_history_table[:updated_by].not_eq(nil))

          reflect(
            @query.where(
              Arel::Nodes::Exists.new(
                Arel::Nodes::UnionAll.new(thing_query, thing_history_query)
              )
            )
          )
        end

        def not_exists_editor
          t_alias = generate_thing_alias
          thing_query = thing
            .project(1)
            .from(t_alias)
            .where(t_alias[:id].eq(thing[:id]))
            .where(t_alias[:updated_by].eq(nil))
          thing_history_query = thing_history_table
            .project(1)
            .where(thing_history_table[:thing_id].eq(thing[:id]))
            .where(thing_history_table[:updated_by].eq(nil))

          reflect(
            @query.where(
              Arel::Nodes::Exists.new(
                Arel::Nodes::UnionAll.new(thing_query, thing_history_query)
              )
            )
          )
        end

        def like_editor(value = nil)
          return self if value&.dig('text').blank?

          t_alias = generate_thing_alias
          thing_query = thing
            .project(1)
            .from(t_alias)
            .where(t_alias[:id].eq(thing[:id]))
            .where(
              user_table
                .project(1)
                .where(t_alias[:updated_by].eq(user_table[:id]))
                .where(user_table[:email].matches("%#{value['text']}"))
                .exists
            )
          thing_history_query = thing_history_table
            .project(1)
            .where(thing_history_table[:thing_id].eq(thing[:id]))
            .where(
              user_table
                .project(1)
                .where(thing_history_table[:updated_by].eq(user_table[:id]))
                .where(user_table[:email].matches("%#{value['text']}"))
                .exists
            )

          reflect(
            @query.where(
              Arel::Nodes::Exists.new(
                Arel::Nodes::UnionAll.new(thing_query, thing_history_query)
              )
            )
          )
        end

        def not_like_editor(value = nil)
          return self if value&.dig('text').blank?

          t_alias = generate_thing_alias
          thing_query = thing
            .project(1)
            .from(t_alias)
            .where(t_alias[:id].eq(thing[:id]))
            .where(
              user_table
                .project(1)
                .where(t_alias[:updated_by].eq(user_table[:id]))
                .where(user_table[:email].matches("%#{value['text']}"))
                .exists
            )
          thing_history_query = thing_history_table
            .project(1)
            .where(thing_history_table[:thing_id].eq(thing[:id]))
            .where(
              user_table
                .project(1)
                .where(thing_history_table[:updated_by].eq(user_table[:id]))
                .where(user_table[:email].matches("%#{value['text']}"))
                .exists
            )

          reflect(
            @query.where.not(
              Arel::Nodes::Exists.new(
                Arel::Nodes::UnionAll.new(thing_query, thing_history_query)
              )
            )
          )
        end

        def shared_with(ids = nil)
          return self if ids.blank?

          datalink_items = DataCycleCore::DataLink.by_receiver(ids).where(permissions: ['read', 'write']).valid.map(&:item)

          return reflect(DataCycleCore::Thing.none) if datalink_items.blank?

          things = datalink_items.grep(DataCycleCore::Thing)
          stored_filters = datalink_items.grep(DataCycleCore::StoredFilter)
          watch_lists = datalink_items.grep(DataCycleCore::WatchList)

          filter_queries = []
          if things.present?
            filter_queries.push(
              DataCycleCore::Thing.select('t.id')
              .from(Arel.sql("(VALUES #{things.pluck(:id).map { |id| "('#{id}'::UUID)" }.join(', ')}) AS t(id)"))
              .to_sql
            )
          end

          filter_queries.push(watch_list_ids_query(watch_lists)) if watch_lists.present?
          filter_queries.push(filter_ids_query(stored_filters)) if stored_filters.present?

          filter_query_sql = filter_queries.compact_blank.join(' UNION ')
          return self if filter_query_sql.blank?

          reflect(@query.where(thing[:id].in(Arel.sql(filter_query_sql))))
        end

        def shared_by_collection_user_shares(ids = nil)
          return self if ids.blank?

          users = DataCycleCore::User.where(id: ids)
          collections = []

          users.each do |user|
            collections.concat(DataCycleCore::Collection.shared_with_user_by_user(user).to_a)
          end

          return reflect(DataCycleCore::Thing.none) if collections.blank?

          union_filter_ids(collections)
        end

        def shared_by_watch_list_shares(ids = nil)
          return self if ids.blank?

          combined_ids = Array.wrap(ids) + DataCycleCore::UserGroup.where(id: DataCycleCore::UserGroupUser.where(user_id: ids)).pluck(:id)

          raw_query = <<~SQL.squish
             SELECT 1
            FROM "watch_list_data_hashes" "wldh"
             INNER JOIN "collection_shares" ON "collection_shares"."collection_id" = "wldh"."watch_list_id"
             WHERE "wldh"."thing_id" = "things"."id"
               AND "collection_shares"."shareable_id" IN (?)
          SQL

          reflect(
            @query.where(
              Arel::Nodes::Exists.new(
                Arel.sql(sanitize_sql([raw_query, combined_ids]))
              )
            )
          )
        end
      end
    end
  end
end
