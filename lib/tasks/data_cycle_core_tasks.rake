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

      use_case = DataCycleCore::UseCase.find_by(external_source_id: options[:external_source_id])

      download_class = Object.const_get("DataCycleCore::#{use_case.external_source.config["download"]}")
      download_job = download_class.new(options[:external_source_id], false, 100, options[:max_count].to_i)
      download_job.download

      import_class = Object.const_get("DataCycleCore::#{use_case.external_source.config["import"]}")
      import_job = import_class.new(options[:external_source_id])
      import_job.import
    end    
  end
end
