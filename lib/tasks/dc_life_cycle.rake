# frozen_string_literal: true

namespace :dc do
  namespace :life_cycle do
    desc 'archive all contents in endpoint'
    task :archive, [:endpoint] => :environment do |_, args|
      abort('Please provide an endpoint to archive') if args.endpoint.blank?

      collection = DataCycleCore::Collection.by_id_name_slug(args.endpoint).first
      abort("No collection found for endpoint: #{args.endpoint}") if collection.nil?

      things = collection.things
      queue = DataCycleCore::WorkerPool.new
      progressbar = ProgressBar.create(total: things.size, title: "Archiving with #{queue.num_workers} threads")

      things.find_each do |thing|
        queue.append do
          puts "archiving failed for ##{thing.id}" unless thing.try(:archive)
          progressbar.increment
        end
      end

      queue.wait!
    end
  end
end
