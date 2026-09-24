# frozen_string_literal: true

class DbHelper
  SUFFIX_FOR_FORMAT = {
    'c' => 'dump',
    'p' => 'sql',
    't' => 'tar',
    'd' => 'dir'
  }.freeze

  FORMAT_FOR_SUFFIX = SUFFIX_FOR_FORMAT.invert.freeze

  # A whole-database dump as `db:dump` names it: <timestamp>_<db>.<suffix>. The dot-free
  # stem is what keeps `db:dump:table` out - that task appends the table to the same stem
  # (20260907120000_dc_production.things.dir), and one table is no restore point.
  WHOLE_DUMP_NAME = /\A\d{14}_[^.]+\.(?:#{FORMAT_FOR_SUFFIX.keys.join('|')})\z/

  class << self
    def ensure_format(format)
      return format if ['c', 'p', 't', 'd'].include?(format)

      FORMAT_FOR_SUFFIX[format] || 'd'
    end

    def suffix_for_format(suffix)
      SUFFIX_FOR_FORMAT[suffix]
    end

    def format_for_file(file)
      case file
      when /\.dump$/ then 'c'
      when /\.sql$/  then 'p'
      when /\.dir$/  then 'd'
      when /\.tar$/  then 't'
      end
    end

    # Everything the timestamped dumps rotate through, newest first. The leading timestamp
    # excludes both the dumps taken under an explicit backup_name (utility/dump_postgres.sh
    # writes <db>.dir for the postgres major upgrade) and the hidden in-progress ones.
    def dump_files(backup_dir)
      Dir.glob("#{backup_dir}/[0-9]*.*").sort_by { |f| File.mtime(f) }.reverse
    end

    def recent_dump(backup_dir, max_age)
      dump_files(backup_dir)
        .find { |f| File.basename(f).match?(WHOLE_DUMP_NAME) && File.mtime(f) > max_age.ago }
    end

    # pg_dump writes toc.dat and every data file as it goes, so an interrupted directory dump
    # passes both `pg_restore -l` and a toc.dat check: a 4s dump of three tables already had
    # all four files in place 2s in. Only the rename out of this hidden name marks it finished.
    def in_progress_path(full_path)
      File.join(File.dirname(full_path), ".in_progress_#{File.basename(full_path)}")
    end

    def backup_directory(suffix = nil, create: false)
      backup_dir = Rails.root.join(*(['db', 'backups'] + Array.wrap(suffix)))

      if create && !Dir.exist?(backup_dir)
        puts "Creating #{backup_dir} .." # rubocop:disable Rails/Output
        FileUtils.mkdir_p(backup_dir)
      end

      backup_dir
    end

    # VACUUM and REINDEX CONCURRENTLY cannot run inside a transaction, so the `SET LOCAL
    # statement_timeout = 0` used everywhere else is unavailable and the session value has to be
    # put back by hand. RESET would restore postgresql.conf's value (0, no timeout at all), not
    # the `statement_timeout: 1min` that database.yml applies through `variables:` on connect.
    def without_statement_timeout
      connection = ActiveRecord::Base.connection
      previous = connection.select_value('SHOW statement_timeout')
      connection.exec_query('SET statement_timeout = 0;')

      yield connection
    ensure
      # nil when the connection or the SHOW above failed, and restoring would mask that error
      connection.exec_query("SET statement_timeout = #{connection.quote(previous)};") if previous
    end

    def with_config
      config = Rails.application.config.database_configuration[Rails.env]

      yield config.values_at('host', 'port', 'database', 'username', 'password')
    end

    def status_relation(data, data_class, linked_class)
      if data.positive?
        puts "[ERROR] Inconsitency for #{linked_class} in #{data_class} (#{data})" # rubocop:disable Rails/Output
      else
        puts "[OK]    checked references, #{data_class} -> #{linked_class}" # rubocop:disable Rails/Output
      end
    end
  end
end
