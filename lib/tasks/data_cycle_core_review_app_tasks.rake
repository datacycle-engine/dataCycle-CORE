# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :review_app do
    desc 'init review app files'
    task :init, [:database_name, :domain] => :environment do |_, args|
      if args[:database_name].nil?
        puts 'Error: database_name not set!'
        exit(-1)
      end
      if args[:domain].nil?
        puts 'Error: domain not set!'
        exit(-1)
      end
      Rails.root.join('tmp', '.env').open('w') do |file|
        file << "POSTGRES_DATABASE=#{args[:database_name]}\n"
        file << "APP_HOST=#{args[:domain]}\n"
        file << "APP_PROTOCOL=http\n"
      end
    end
  end
end
