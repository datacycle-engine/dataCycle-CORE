# frozen_string_literal: true

class DbHelper
  class << self
    def ensure_format(format)
      return format if ['c', 'p', 't', 'd'].include?(format)

      case format
      when 'dump' then 'c'
      when 'sql' then 'p'
      when 'tar' then 't'
      when 'dir' then 'd'
      else 'd'
      end
    end

    def suffix_for_format(suffix)
      case suffix
      when 'c' then 'dump'
      when 'p' then 'sql'
      when 't' then 'tar'
      when 'd' then 'dir'
      end
    end

    def format_for_file(file)
      case file
      when /\.dump$/ then 'c'
      when /\.sql$/  then 'p'
      when /\.dir$/  then 'd'
      when /\.tar$/  then 't'
      end
    end

    def backup_directory(suffix = nil, create: false)
      backup_dir = Rails.root.join(*(['db', 'backups'] + Array.wrap(suffix)))

      if create && !Dir.exist?(backup_dir)
        puts "Creating #{backup_dir} .." # rubocop:disable Rails/Output
        FileUtils.mkdir_p(backup_dir)
      end

      backup_dir
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
