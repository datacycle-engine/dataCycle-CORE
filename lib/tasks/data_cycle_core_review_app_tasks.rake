namespace :data_cycle_core do
  namespace :review_app do
    desc 'init review app files'
    task :init, [:database_name] => :environment do |_, args|
      if args[:database_name].nil?
        puts 'Error: database_name not set!'
        exit(-1)
      end
      File.open(Rails.root.join('tmp', '.env'), 'w') do |file|
        file << "POSTGRES_DATABASE=#{args[:database_name]}\n"
      end
    end
  end
end
