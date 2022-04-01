# frozen_string_literal: true

module DataCycleCore
  class StatsDatabase
    attr_accessor(
      :stat_update, :pg_name, :pg_size, :pg_overlays,
      :pg_content_history, :mongo_categories,
      :mongo_pois, :mongo_regions, :import_modules,
      :pg_tables
    )

    EXCLUDED_TABLES = [
      'ar_internal_metadata',
      'schema_migrations',
      'spatial_ref_sys'
    ].freeze

    def initialize(user_id, stats_only = false)
      update(user_id, stats_only)
    end

    def update(user_id, stats_only = false)
      if stats_only
        load_pg_stats
      else
        @import_modules = []
        load_postgres_data
        load_mongo_data(user_id)
      end

      self
    end

    def load_pg_stats
      @pg_tables = {}

      stats_sql = <<-SQL.squish
        SELECT
          relname AS tablename,
          pg_total_relation_size(relid) AS total_size,
          pg_table_size(relid) AS data_size,
          pg_indexes_size(relid) AS index_size
        FROM
          pg_catalog.pg_statio_user_tables
        WHERE
          relname NOT IN (?)
        ORDER BY
          pg_total_relation_size(relid) DESC;
      SQL

      stats_res = ActiveRecord::Base.connection.execute(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [stats_sql, EXCLUDED_TABLES]))
      stats_res.each do |stat_res|
        @pg_tables[stat_res['tablename']] = stat_res.except('tablename')
      end

      count_sql = @pg_tables.keys.map { |t_name| "SELECT '#{t_name}' AS tablename, count(*) AS count FROM #{t_name}" }.join(' UNION ')
      count_res = ActiveRecord::Base.connection.execute(ActiveRecord::Base.send(:sanitize_sql_for_conditions, count_sql))
      count_res.each do |count_r|
        @pg_tables[count_r['tablename']]['count'] = count_r['count']
      end
    end

    private

    def load_postgres_data
      @stat_update = Time.zone.now

      @pg_name = ActiveRecord::Base.connection.current_database
      sql = ActiveRecord::Base.send(:sanitize_sql_for_conditions, "SELECT pg_database_size('#{@pg_name}');")
      @pg_size = ActiveRecord::Base.connection.execute(sql).first['pg_database_size']
    end

    def load_mongo_data(_user_id)
      mongo_dbs = Generic::Collection.mongo_client.list_databases

      DataCycleCore::ExternalSystem.where('external_systems.config ? :key', key: 'import_config').find_each do |external_source|
        import_name = external_source.name
        next if external_source.config.blank?

        Mongoid.override_database(nil)
        mongo_database = "#{Generic::Collection.database_name}_#{external_source.id}"
        Mongoid.override_database(mongo_database)
        mongo_dbs_index = mongo_dbs.find_index { |db| db['name'] == mongo_database }

        if mongo_dbs_index.nil?
          @import_modules.push(
            {
              uuid: external_source.id,
              deactivated: external_source.deactivated || false,
              downloadable: external_source.download_config.present?,
              importable: external_source.import_config.present? && external_source.download_config.blank?,
              name: import_name,
              database: mongo_database,
              db_size: 0,
              tables: {
                "no collections found": ['', '']
              },
              last_import: 'never',
              last_download: 'never',
              last_successful_import: 'never',
              last_successful_download: 'never'
            }
          )
        else
          mongo_dbsize = mongo_dbs[mongo_dbs_index]['sizeOnDisk']
          Mongoid.clients[external_source.id] = {
            'database' => mongo_database,
            'hosts' => Mongoid.default_client.cluster.servers.map(&:address).map { |adr| "#{adr.host}:#{adr.port}" },
            'options' => nil
          }
          mongo_data = Hash[
            Mongoid
              .client(external_source.id)
              .collections
              .map do |item|
                deleted = item.find('dump.de.deleted_at' => { '$exists' => true }).count
                archived = item.find('dump.de.archived_at' => { '$exists' => true }).count
                info = []
                if deleted.positive? || archived.positive?
                  info = ['(']
                  info += ["D:#{deleted}"] if deleted.positive?
                  info += [', '] if deleted.positive? && archived.positive?
                  info += ["A:#{archived}"] if archived.positive?
                  info += [')']
                end
                [item.name.humanize, [item.count, info.join('')]]
              end
          ]

          last_download = external_source.last_download.presence || 'never'
          last_import = external_source.last_import.presence || 'never'
          last_successful_download = external_source.last_successful_download.presence || 'never'
          last_successful_import = external_source.last_successful_import.presence || 'never'

          @import_modules.push(
            {
              uuid: external_source.id,
              deactivated: external_source.deactivated || false,
              downloadable: external_source.download_config.present?,
              importable: external_source.import_config.present? && (external_source.download_config.blank? || mongo_dbsize&.positive?),
              name: import_name,
              database: mongo_database,
              db_size: mongo_dbsize,
              tables: mongo_data,
              last_download: last_download,
              last_import: last_import,
              last_successful_download: last_successful_download,
              last_successful_import: last_successful_import
            }
          )
        end
      end
      Mongoid.override_database(nil)
    end
  end
end
