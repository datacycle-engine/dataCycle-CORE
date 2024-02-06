# frozen_string_literal: true

module DataCycleCore
  module Content
    module Searchable
      def with_content_type(type)
        where(content_type: type)
      end

      def with_schema_type(type)
        where("thing_templates.schema ->> 'schema_type' = :type OR thing_templates.computed_schema_types && ARRAY[:type]::VARCHAR[]", type:)
      end

      def without_template_names(*names)
        where.not(template_name: names)
      end

      def with_template_names(*names)
        where(template_name: names)
      end

      def with_default_data_type(classification_alias_names)
        template_types = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').where(internal_name: classification_alias_names).with_descendants.pluck(:internal_name)

        where("schema -> 'properties' -> 'data_type' ->> 'default_value' IN (?)", template_types)
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

        join_external_connections_query = <<-SQL.squish
          INNER JOIN (
            SELECT DISTINCT ON (thing_id) *
            FROM (
              SELECT
                external_system_syncs.syncable_id AS thing_id,
                external_system_syncs.external_system_id AS external_system_id,
                external_system_syncs.external_key AS external_key
              FROM
                external_system_syncs
              WHERE
                external_system_syncs.syncable_type = 'DataCycleCore::Thing'
                AND external_system_syncs.external_system_id = :external_system_id
                AND external_system_syncs.external_key IN (:external_key)
              UNION
              SELECT
                things.id AS thing_id,
                things.external_source_id AS external_system_id,
                things.external_key AS external_key
              FROM
                things
              WHERE
                things.external_source_id = :external_system_id
                AND things.external_key IN (:external_key)

            ) union_external_keys
          ) #{joined_name}
          ON #{joined_name}.thing_id = things.id
        SQL

        joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [join_external_connections_query, external_system_id:, external_key: external_key.is_a?(Array) ? external_key.map(&:to_s) : external_key.to_s]))
      end

      def first_by_external_key_or_id(external_key, external_system_id)
        return if external_key.blank?

        query = '(external_source_id = :external_system_id AND external_key = :external_key)'
        query += ' OR id = :external_key' if external_key.uuid?

        DataCycleCore::Thing.find_by(query, external_system_id:, external_key:)
      end

      def by_external_system(external_system_id, joined_name = 'merged_external_systems')
        return all.none if external_system_id.blank?

        join_external_connections_query = <<-SQL.squish
          INNER JOIN (
            SELECT DISTINCT on (thing_id) *
            FROM (
              SELECT
                external_system_syncs.syncable_id AS thing_id,
                external_system_syncs.external_system_id AS external_system_id
              FROM
                external_system_syncs
              WHERE
                external_system_syncs.syncable_type = 'DataCycleCore::Thing'
                AND external_system_syncs.external_system_id = :external_system_id
              UNION
              SELECT
                things.id AS thing_id,
                things.external_source_id AS external_system_id
              FROM
                things
              WHERE
                things.external_source_id = :external_system_id
            ) union_external_keys
          ) #{joined_name}
          ON #{joined_name}.thing_id = things.id
        SQL

        joins(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [join_external_connections_query, external_system_id:]))
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
        # by id (primary external_system_sync)
        content = all.find_by(id:) if id.is_a?(::String) && id.uuid?

        # by external_key
        content ||= all.by_external_key(external_system.id, external_key).first

        # by external_system_syncs for current_instance_identifier
        content ||= first_by_current_identified_syncs(external_system:, external_system_syncs:)

        # by primary external_system_sync for existing external_systems
        content ||= first_by_primary_sync(external_system:, external_system_syncs:)

        # by external_system_syncs for existing external_systems
        content ||= first_by_existing_syncs(external_system:, external_system_syncs:)

        content
      end

      def first_by_current_identified_syncs(external_system:, external_system_syncs:)
        return if external_system.nil? || external_system_syncs.blank?

        current_identifiers = Array.wrap(external_system.default_options['current_instance_identifiers'])
        return if current_identifiers.blank?

        current_ids = Array.wrap(external_system_syncs).filter { |sync| current_identifiers.include?(sync['identifier'] || sync['name']) }.pluck('external_key')
        return if current_ids.blank?

        all.find_by(id: current_ids)
      end

      def first_by_primary_sync(external_system:, external_system_syncs:)
        return if external_system.nil? || external_system_syncs.blank?

        primary_sync = Array.wrap(external_system_syncs).detect { |sync| sync['primary'] }

        return if primary_sync.nil? || primary_sync['external_key'].blank?

        primary_system = DataCycleCore::ExternalSystem.find_by(identifier: primary_sync['identifier'] || primary_sync['name'])

        return if primary_system.nil?

        all.by_external_key(primary_system.id, primary_sync['external_key']).first
      end

      def first_by_existing_syncs(external_system:, external_system_syncs:)
        return if external_system.nil? || external_system_syncs.blank?

        current_identifiers = Array.wrap(external_system.default_options['current_instance_identifiers'])
        external_systems = DataCycleCore::ExternalSystem.where(identifier: Array.wrap(external_system_syncs).map { |sync| sync['identifier'] || sync['name'] }).index_by(&:identifier)

        external_system_syncs.each do |sync|
          next if sync['external_key'].blank?
          next if current_identifiers.include?(sync['identifier'] || sync['name'])

          es = external_systems[sync['identifier'] || sync['name']]

          next if es.nil?

          content = all.by_external_key(es.id, sync['external_key']).first
          return content unless content.nil?
        end

        nil
      end

      # Deprecated: no replacement
      def without_classification_alias_ids(_classification_alias_ids)
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end

      # Deprecated: no replacement
      def with_classification_alias_names(*_names)
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end

      # Deprecated: no replacement
      def search(_q, _language)
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end
    end
  end
end
