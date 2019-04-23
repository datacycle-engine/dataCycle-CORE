# frozen_string_literal: true

module Translations
  module Test
    class Database
      class << self
        def connect(orm)
          case orm
          when 'active_record'
            ::ActiveRecord::Base.establish_connection config[driver]
            ::ActiveRecord::Migration.verbose = false if in_memory?

            # don't really need this, but let's return something relevant
            ::ActiveRecord::Base.connection
          end
        end

        def auto_migrate
          Schema.migrate :up if in_memory?
        end

        def config
          @config ||= YAML.safe_load(File.open(File.expand_path('databases.yml', __dir__)))
        end

        def driver
          (ENV['DB'] || 'sqlite3').downcase
        end

        def in_memory?
          config[driver]['database'] == ':memory:'
        end
      end
    end
  end
end
