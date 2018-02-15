namespace :data_cycle_core do
  namespace :review_app do
    desc 'init review app files'
    task :init, [:application] => :environment do |_, args|
      if args[:application].nil?
        puts 'Error: application not set!'
        exit(-1)
      end
      File.open(Rails.root.join('tmp', '.env'), 'w') do |file|
        file << "POSTGRES_DATABASE=data-cycle-base_#{args[:application]}\n"
      end
    end
  end
end