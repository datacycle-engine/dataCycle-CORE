# frozen_string_literal: true

# Strip per-stored-filter SQL functions from the dumped db/structure.sql.
#
# Named stored filters get a generated SQL-representation function in the
# `public` schema (see DataCycleCore::StoredFilter#sql_representation_name),
# named `stored_filter_<uuid>()`. These are runtime data, not schema, so they
# would otherwise churn db/structure.sql on every dump.
#
# pg_dump has no flag to exclude functions by name (only -N schema / -T table),
# so we post-process the dump instead. Removing them is safe: the resolver
# (search_cached_result) treats a missing function as an empty result set, so
# schema loads (db:test:prepare, db:schema:load) work without them, and they are
# recreated when the filters are synced.

# A pg_dump object section starts with a "-- Name: ...; Type: ...; Schema: ..."
# comment header. This matches the header of a generated stored_filter function
# (uuid with '-' replaced by '_'); it deliberately does NOT match the
# stored_filter_caches table, stored_filter_id columns or the helper functions.
DC_GENERATED_FILTER_FUNCTION = /\A--\n-- Name: stored_filter_\h{8}_\h{4}_\h{4}_\h{4}_\h{12}\(\); Type: FUNCTION;/

if Rake::Task.task_defined?('db:schema:dump')
  Rake::Task['db:schema:dump'].enhance do
    next unless ActiveRecord.schema_format == :sql

    paths = ActiveRecord::Base.configurations
      .configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env, include_hidden: false)
      .filter_map { |config| ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(config, :sql) }
      .uniq
      .select { |path| File.exist?(path) }

    paths.each do |path|
      # Split into pg_dump object sections (each begins with its "-- Name:" header)
      # and drop the generated stored_filter function sections.
      sections = File.read(path).split(/(?=^--\n-- Name: )/)
      kept = sections.grep_v(DC_GENERATED_FILTER_FUNCTION)
      removed = sections.size - kept.size
      next if removed.zero?

      File.write(path, kept.join)
    end
  end
end
