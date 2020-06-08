# frozen_string_literal: true

namespace :dc do
  namespace :local_dev do
    # RAILS_ENV=development rake dc:local_dev:init
    desc 'init new lokal project'
    task init: :environment do
      Rake::Task['db:create'].invoke
      Rake::Task['db:migrate'].invoke
      Rake::Task['db:seed'].invoke
      Rake::Task['data_cycle_core:update:import_classifications'].invoke
      Rake::Task['data_cycle_core:update:import_external_system_configs'].invoke
      Rake::Task['data_cycle_core:update:import_templates'].invoke
    end

    desc 'init env file'
    task :init_env, [:application_name, :domain] => :environment do |_, args|
      if args[:application_name].nil?
        puts 'Error: application_name not set!'
        exit(-1)
      end
      if args[:domain].nil?
        puts 'Error: domain not set!'
        exit(-1)
      end

      input = prompt 'Please enter Postgres Password'

      if input.present?
        File.open(Rails.root.join('tmp', '.env'), 'w') do |file|
          file << "POSTGRES_USER=#{args[:application_name]}\n"
          file << "POSTGRES_DATABASE=#{args[:application_name]}_production\n"
          file << "POSTGRES_PASSWORD=#{input}\n"
          file << "SECRET_KEY_BASE=#{SecureRandom.hex(64)}\n"
          file << "REDIS_SERVER=localhost\n"
          file << "REDIS_PORT=6379\n"
          file << "REDIS_CACHE_DATABASE=2\n"
          file << "REDIS_CABLE_DATABASE=10\n"
          file << "REDIS_CACHE_NAMESPACE=#{args[:application_name]}_production\n"

          file << "APP_HOST=#{args[:domain]}\n"
          file << "APP_PROTOCOL=http\n"

          file << "APPSIGNAL_APP_NAME=#{args[:domain]}\n"
        end
      end
    end
    def prompt(*args)
      print(*args)
      STDIN.gets.strip
    end
  end
end
