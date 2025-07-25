# frozen_string_literal: true

require 'fugit'

module DataCycleCore
  class StatsDatabase
    include ActionView::Helpers::NumberHelper

    VALID_JOB_TYPES = {
      'dc:import:append_job' => [:key, :mode, :inline],
      'dc:import:append_partial_job' => [:key, :download_names, :import_names, :mode],
      'dc:downport:partial' => [:key, :download_names, :import_names, :mode, :max_count],
      'data_cycle_core:import:perform' => [:key, :mode, :max_count]
    }.freeze

    attr_accessor(
      :stat_update, :pg_name, :pg_size, :pg_overlays,
      :pg_content_history, :mongo_categories,
      :mongo_pois, :mongo_regions, :import_modules
    )

    EXCLUDED_TABLES = [
      'ar_internal_metadata',
      'schema_migrations',
      'spatial_ref_sys'
    ].freeze

    def load_all_stats
      @import_modules = {}
      load_postgres_data
      load_mongo_data

      self
    end

    def load_pg_stats
      pg_tables = {}

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

      stats_res = ActiveRecord::Base.connection.select_all(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [stats_sql, EXCLUDED_TABLES]))
      stats_res.each do |stat_res|
        pg_tables[stat_res['tablename']] = stat_res.except('tablename')
      end

      count_sql = pg_tables.keys.map { |t_name| "SELECT '#{t_name}' AS tablename, count(*) AS count FROM #{t_name}" }.join(' UNION ')
      count_res = ActiveRecord::Base.connection.select_all(ActiveRecord::Base.send(:sanitize_sql_for_conditions, count_sql))
      count_res.each do |count_r|
        pg_tables[count_r['tablename']]['count'] = count_r['count']
      end

      pg_tables
    end

    def load_mongo_stats(external_system_id)
      mongo_host = ENV['MONGODB_HOST']
      external_source = DataCycleCore::ExternalSystem.find(external_system_id)

      mongo_connection_string = "mongodb://#{mongo_host}:27017"
      client = Mongo::Client.new(mongo_connection_string)

      mongo_dbs = client.database_names
      mongo_database = "#{Generic::Collection.database_name}_#{external_source.id}"

      mongo_dbsize = 0
      if mongo_dbs.include?(mongo_database)
        db_stats = client.use(mongo_database).database.command(dbStats: 1).first
        mongo_dbsize = db_stats['dataSize']
      end

      db_client = Mongo::Client.new(mongo_connection_string, database: mongo_database)

      # Get collections and their stats in parallel
      collection_stats = Concurrent::Array.new
      threads = db_client.collections.map do |collection|
        Thread.new do
          pipeline = [
            {
              '$facet' => {
                'deleted' => [
                  { '$match' => { '$or' => [
                    { 'dump.deleted_at' => { '$exists' => true } },
                    { 'dump.de.deleted_at' => { '$exists' => true } }
                  ] } },
                  { '$count' => 'count' }
                ],
                'archived' => [
                  { '$match' => { '$or' => [
                    { 'dump.archived_at' => { '$exists' => true } },
                    { 'dump.de.archived_at' => { '$exists' => true } }
                  ] } },
                  { '$count' => 'count' }
                ],
                'total' => [
                  { '$count' => 'count' }
                ]
              }
            }
          ]
          result = collection.aggregate(pipeline).first
          deleted = result['deleted'].first&.fetch('count', 0) || 0
          archived = result['archived'].first&.fetch('count', 0) || 0
          total = result['total'].first&.fetch('count', 0) || 0

          info = []
          if deleted.positive? || archived.positive?
            info << "D: #{number_with_delimiter(deleted)}" if deleted.positive?
            info << "A: #{number_with_delimiter(archived)}" if archived.positive?
            info = "(#{info.join(', ')})"
          end
          collection_stats << [collection.name.humanize, [number_with_delimiter(total), info.presence || '']]
        end
      end

      threads.each(&:join)

      collection_stats = collection_stats.sort_by(&:first)

      mongo_data = collection_stats.to_h.presence

      data = {
        uuid: external_source.id,
        deactivated: external_source.deactivated || false,
        downloadable: external_source.download_config.present?,
        importable: external_source.import_config.present? && (external_source.download_config.blank? || mongo_dbsize&.positive?),
        name: external_source.name,
        database: mongo_database,
        db_size: number_to_human_size(mongo_dbsize),
        tables: mongo_data,
        languages: external_source.default_options&.dig('locales'),
        credentials: external_source.credentials.is_a?(::Array) ? number_with_delimiter(external_source.credentials.size) : 1,
        updated_at: external_source.updated_at,
        sorted_step_times: external_source.sorted_step_times
      }.merge(last_download_and_import(external_source))

      client.close
      db_client.close

      data
    end

    private

    def schedule(external_source)
      schedules = []

      DataCycleCore.schedule.each do |config|
        next if config.key?('type') || config.key?('task')

        config&.each do |cron_rule, tasks|
          tasks&.each do |task|
            t_name, t_args = task.delete_suffix(']').split('[')
            next unless VALID_JOB_TYPES.key?(t_name.to_s)

            opts = VALID_JOB_TYPES[t_name.to_s].zip(t_args.split(',')).to_h
            next if opts[:key].blank?

            opts.transform_values! { |v| v&.delete('\'"') }

            next if opts[:key].start_with?(' ') ||
                    opts[:key].end_with?(' ') ||
                    opts[:mode]&.include?(' ') ||
                    opts[:inline]&.include?(' ')

            next unless opts[:key] == external_source.id ||
                        opts[:key] == external_source.name ||
                        opts[:key] == external_source.identifier

            parsed_schedule = Fugit.parse(cron_rule)
            next unless parsed_schedule

            steps = []
            steps = opts[:download_names].to_s.split('|').map(&:strip).compact_blank if opts[:download_names].present?
            steps += opts[:import_names].to_s.split('|').map(&:strip).compact_blank if opts[:import_names].present?

            parsed_schedule.next.take(7).map do |next_time|
              schedules << {
                timestamp: next_time,
                mode: opts[:mode],
                inline: opts[:inline].to_s == 'true',
                steps: steps.uniq
              }
            end
          end
        end
      end

      schedules.sort_by { |s| s[:timestamp] }.first(7)
    end

    def load_postgres_data
      @stat_update = Time.zone.now

      @pg_name = ActiveRecord::Base.connection.current_database
      sql = ActiveRecord::Base.send(:sanitize_sql_for_conditions, "SELECT pg_database_size('#{@pg_name}');")
      @pg_size = ActiveRecord::Base.connection.select_all(sql).first['pg_database_size']
    end

    def last_download_and_import(external_source)
      external_source.last_download_and_import
    end

    def load_mongo_data
      mongo_dbs = Generic::Collection.mongo_client.list_databases

      DataCycleCore::ExternalSystem.where("external_systems.config ? 'import_config'").find_each do |external_source|
        mongo_database = "#{Generic::Collection.database_name}_#{external_source.id}"
        mongo_dbs_index = mongo_dbs.find_index { |db| db['name'] == mongo_database }
        mongo_dbsize = mongo_dbs_index&.then { |i| mongo_dbs.dig(i, 'sizeOnDisk') } || 0

        @import_modules[external_source.id] = {
          uuid: external_source.id,
          deactivated: external_source.deactivated || false,
          downloadable: external_source.download_config.present?,
          importable: external_source.import_config.present? && (external_source.download_config.blank? || mongo_dbsize&.positive?),
          name: external_source.name,
          identifier: external_source.identifier,
          last_import_step_time_info: external_source.last_import_step_time_info,
          schedule: schedule(external_source)
        }.merge(last_download_and_import(external_source))
      end
    end
  end
end
