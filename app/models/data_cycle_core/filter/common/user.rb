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

          sub_query = DataCycleCore::User
            .select(1)
            .where(thing[key].eq(user_table[:id]))
            .where(user_table[:email].matches("%#{value['text']}"))
            .arel
            .exists

          reflect(@query.where(sub_query))
        end

        def not_like_user(value = nil, type = nil)
          return self if value&.dig('text').blank? || type.blank?

          key = KEY_MAPPING[type.to_s]&.to_sym
          return not_like_editor(value) if key.blank?

          sub_query = DataCycleCore::User
            .select(1)
            .where(thing[key].eq(user_table[:id]))
            .where(user_table[:email].matches("%#{value['text']}"))
            .arel
            .exists

          reflect(@query.where.not(sub_query))
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

          data_links = DataCycleCore::DataLink.by_receiver(ids).where(permissions: ['read', 'write']).valid

          filter_queries = []
          filter_queries.push(data_links.where(item_type: 'DataCycleCore::Thing').select(:item_id).except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS).to_sql)

          filter_queries.push(DataCycleCore::WatchListDataHash.where(watch_list_id: data_links.where(item_type: ['DataCycleCore::WatchList', 'DataCycleCore::Collection']).select(:item_id)).select(:thing_id).except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS).to_sql)

          filter_queries.push(DataCycleCore::StoredFilter.where(id: data_links.where(item_type: ['DataCycleCore::StoredFilter', 'DataCycleCore::Collection']).select(:item_id)).map { |f| f.apply(skip_ordering: true).select(:id).except(*DataCycleCore::Filter::Common::Union::UNION_FILTER_EXCEPTS).to_sql }.join(' UNION '))

          reflect(
            @query.where(thing[:id].in(Arel.sql(filter_queries.compact_blank.join(' UNION '))))
          )
        end

        def shared_by_collection_user_shares(ids = nil)
          return self if ids.blank?

          users = DataCycleCore::User.where(id: ids)
          collection_ids = []

          users.each do |user|
            collection_ids.concat(DataCycleCore::Collection.shared_with_user_by_user(user).pluck(:id))
          end

          return reflect(@query.where('1 = 0')) if collection_ids.blank?

          union_filter_ids(collection_ids)
        end

        def shared_by_watch_list_shares(ids = nil)
          return self if ids.blank?

          combined_ids = Array.wrap(ids) + DataCycleCore::UserGroup.where(id: DataCycleCore::UserGroupUser.where(user_id: ids)).pluck(:id)

          raw_query = <<-SQL.squish
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
