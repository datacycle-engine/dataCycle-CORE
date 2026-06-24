# frozen_string_literal: true

module DataCycleCore
  module Content
    module Searchable
      extend ActiveSupport::Concern

      included do
        scope :with_translation, lambda { |locale = I18n.locale|
          joins(:translations).where(thing_translations: { locale: locale })
        }
        scope :with_locale, lambda { |locale|
          thing_translations = DataCycleCore::Thing::Translation.arel_table
          subquery = DataCycleCore::Thing::Translation
            .select(1)
            .where(locale: locale)
            .where(thing_translations[:thing_id].eq(arel_table[:id]))
            .arel
            .exists

          where(subquery)
        }
      end

      class_methods do
        def with_content_type(type)
          where(content_type: type)
        end

        def with_schema_type(type)
          where("thing_templates.schema ->> 'schema_type' = :type OR thing_templates.api_schema_types && ARRAY[:type]::VARCHAR[]", type:)
        end

        def without_template_names(*names)
          where.not(template_name: names)
        end

        def with_template_names(*names)
          where(template_name: names)
        end

        def with_default_data_type(classification_alias_names)
          template_types = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen')
            .where(internal_name: classification_alias_names)
            .with_descendants
            .pluck(:internal_name)

          includes(:thing_template)
            .where("thing_templates.schema -> 'properties' -> 'data_type' ->> 'default_value' IN (?)", template_types)
        end

        def expired_not_release_id(id)
          return unless DataCycleCore::Feature::Releasable.enabled?

          joins(:classifications)
            .where(classification_contents: { relation: DataCycleCore::Feature::Releasable.attribute_keys.first })
            .where.not(classification_contents: { classification_id: id })
        end

        def expired_not_life_cycle_id(id)
          return if DataCycleCore::Feature::LifeCycle.attribute_keys.blank?

          joins(:classifications)
            .where(classification_contents: { relation: DataCycleCore::Feature::LifeCycle.attribute_keys.first })
            .where.not(classification_contents: { classification_id: id })
        end

        def by_external_key(external_system_id, external_key, joined_name = 'merged_external_systems')
          return all.none if external_system_id.blank? || external_key.blank?

          subquery, subparams = by_external_key_subquery(external_system_id, external_key, 1)

          join_external_connections_query = <<~SQL.squish
            INNER JOIN (
              SELECT DISTINCT ON (thing_id) *
              FROM (#{subquery}) union_external_keys
              ORDER BY thing_id, order_column ASC
            ) #{joined_name}
            ON #{joined_name}.thing_id = things.id
          SQL

          joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [join_external_connections_query, subparams]))
            .order("#{joined_name}.order_column ASC")
        end

        def first_by_external_key_or_id(external_key, external_system_id)
          return if external_key.blank?

          query = '(external_source_id = :external_system_id AND external_key = :external_key)'
          query += ' OR id = :external_key' if external_key.to_s.uuid?

          DataCycleCore::Thing.find_by(query, external_system_id:, external_key:)
        end

        def by_external_system(external_system_id, joined_name = 'merged_external_systems')
          return all.none if external_system_id.blank?

          join_external_connections_query = <<~SQL.squish
            INNER JOIN (
              SELECT DISTINCT on (thing_id) *
              FROM (
                SELECT
                  things.id AS thing_id,
                  things.external_source_id AS external_system_id,
                  0 AS order_column
                FROM
                  things
                WHERE
                  things.external_source_id = :external_system_id
                UNION
                SELECT
                  external_system_syncs.syncable_id AS thing_id,
                  external_system_syncs.external_system_id AS external_system_id,
                  1 AS order_column
                FROM
                  external_system_syncs
                WHERE
                  external_system_syncs.syncable_type = 'DataCycleCore::Thing'
                  AND external_system_syncs.external_system_id = :external_system_id
              ) union_external_keys
              ORDER BY thing_id, order_column ASC
            ) #{joined_name}
            ON #{joined_name}.thing_id = things.id
          SQL

          joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [join_external_connections_query, { external_system_id: }]))
            .order("#{joined_name}.order_column ASC")
        end

        # TODO: currently not replaceable: used in PulicationsController
        def with_classification_alias_ids(classification_alias_ids)
          classification_alias_ids = Array(classification_alias_ids).map { |id|
            "'#{id}'"
          }.join(',')

          virtual_table_name = "contents_#{SecureRandom.hex}"

          joins(
            <<-SQL.gsub(/\s+/, ' ')
          JOIN (
            WITH RECURSIVE recursive_classification_trees AS (
              SELECT *
              FROM classification_trees
              WHERE classification_trees.parent_classification_alias_id IN (#{classification_alias_ids})
              OR classification_trees.classification_alias_id IN (#{classification_alias_ids})
              UNION ALL
              SELECT classification_trees.*
              FROM classification_trees
              INNER JOIN recursive_classification_trees
                ON classification_trees.parent_classification_alias_id = recursive_classification_trees.classification_alias_id
            )
            SELECT DISTINCT content_data_id
            FROM classification_contents
            JOIN classification_groups
              ON classification_contents.classification_id = classification_groups.classification_id
            JOIN recursive_classification_trees
              ON recursive_classification_trees.classification_alias_id = classification_groups.classification_alias_id
            WHERE classification_groups.deleted_at IS NULL AND recursive_classification_trees.deleted_at IS NULL
          ) AS #{virtual_table_name}
            ON things.id = #{virtual_table_name}.content_data_id
            SQL
          )
        end

        def first_by_id_or_external_data(id:, external_key:, external_system:, external_system_syncs:)
          subqueries = []
          subqueries << by_ids_subquery(id)
          subqueries << by_external_key_subquery(external_system.id, external_key, 1)
          subqueries << by_current_identified_syncs_subquery(external_system, external_system_syncs, 3)
          subqueries << by_primary_sync_subquery(external_system, external_system_syncs, 4)
          subqueries.concat(by_existing_syncs_subquery(external_system, external_system_syncs, 6))
          subqueries.compact_blank!

          return if subqueries.blank?

          union_queries = subqueries.map { |sq, _| sq }.join(' UNION ')
          union_params = subqueries.reduce({}) { |acc, (_, params)| acc.merge(params) }

          joins = <<~SQL.squish
            INNER JOIN (
              SELECT DISTINCT ON (thing_id) *
              FROM (#{union_queries}) union_external_keys
              ORDER BY thing_id, order_column ASC
            ) merged_external_systems
            ON merged_external_systems.thing_id = things.id
          SQL

          joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [joins, union_params]))
            .order('merged_external_systems.order_column ASC')
            .first
        end

        def by_ids_subquery(ids, starting_order = 0)
          ids = Array.wrap(ids)
          return [] unless ids.present? && ids.all? { |v| v.is_a?(::String) && v.uuid? }

          key = :"id#{starting_order}"

          subquery = <<~SQL.squish
            SELECT things.id AS thing_id,
              things.external_source_id AS external_system_id,
              things.external_key AS external_key,
              #{starting_order.to_i} AS order_column
            FROM things
            WHERE things.id IN (:#{key})
          SQL

          [subquery, { key => ids }]
        end

        def by_external_key_subquery(external_system_id, external_key, starting_order = 1)
          return [] if external_system_id.blank? || external_key.blank?

          es_key = :"id#{starting_order}"
          ek_key = :"ek#{starting_order}"

          subquery = <<~SQL.squish
              SELECT things.id AS thing_id,
                things.external_source_id AS external_system_id,
                things.external_key AS external_key,
                #{starting_order.to_i} AS order_column
              FROM things
              WHERE things.external_source_id = :#{es_key}
                AND things.external_key IN (:#{ek_key})
            UNION
            SELECT external_system_syncs.syncable_id AS thing_id,
              external_system_syncs.external_system_id AS external_system_id,
              external_system_syncs.external_key AS external_key,
              #{starting_order.to_i + 1} AS order_column
            FROM external_system_syncs
            WHERE external_system_syncs.syncable_type = 'DataCycleCore::Thing'
              AND external_system_syncs.external_system_id = :#{es_key}
              AND external_system_syncs.external_key IN (:#{ek_key})
          SQL

          [subquery, { es_key => external_system_id, ek_key => Array.wrap(external_key).map(&:to_s) }]
        end

        def by_current_identified_syncs_subquery(external_system, external_system_syncs, starting_order = 3)
          return [] if external_system.nil? || external_system_syncs.blank?

          current_identifiers = Array.wrap(external_system.default_options['current_instance_identifiers'])
          return [] if current_identifiers.blank?

          current_ids = Array.wrap(external_system_syncs).filter { |sync| current_identifiers.include?(sync['identifier'] || sync['name']) }.pluck('external_key')

          by_ids_subquery(current_ids, starting_order)
        end

        def by_primary_sync_subquery(external_system, external_system_syncs, starting_order = 4)
          return [] if external_system.nil? || external_system_syncs.blank?

          primary_sync = Array.wrap(external_system_syncs).detect { |sync| sync['primary'] }
          return [] if primary_sync.nil? || primary_sync['external_key'].blank?

          primary_system = DataCycleCore::ExternalSystem.find_by(identifier: primary_sync['identifier'] || primary_sync['name'])
          return [] if primary_system.nil?

          by_external_key_subquery(primary_system.id, primary_sync['external_key'], starting_order)
        end

        def by_existing_syncs_subquery(external_system, external_system_syncs, starting_order = 6)
          return [] if external_system.nil? || external_system_syncs.blank?

          current_identifiers = Array.wrap(external_system.default_options['current_instance_identifiers'])
          external_systems = DataCycleCore::ExternalSystem.where(identifier: Array.wrap(external_system_syncs).map { |sync| sync['identifier'] || sync['name'] }).index_by(&:identifier)

          subqueries = []

          external_system_syncs.each do |sync|
            next if sync['external_key'].blank?
            next if current_identifiers.include?(sync['identifier'] || sync['name'])

            es = external_systems[sync['identifier'] || sync['name']]
            next if es.nil?

            subquery, params = by_external_key_subquery(es.id, sync['external_key'], starting_order)
            subqueries << [subquery, params]

            starting_order += 2
          end

          subqueries
        end
      end
    end
  end
end
