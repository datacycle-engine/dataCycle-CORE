namespace :data_cycle_core do
  namespace :import do
    desc "List available endpoints for import"
    task :list => :environment do
      DataCycleCore::ExternalSource.all.each do |external_source|
        puts "#{external_source.id} - #{external_source.name}"
      end
    end

    task :perform, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = {max_count: 1000}.merge(args.to_h)

      download_job = DataCycleCore::Jsonld::Download.new(options[:external_source_id], false, 100, options[:max_count].to_i)
      download_job.download

      import_job = DataCycleCore::Jsonld::Import.new(options[:external_source_id])
      import_job.import
    end    
  end
end
