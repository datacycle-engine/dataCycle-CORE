FIXNUM_MAX = (2**(0.size * 8 -2) -1)

namespace :data_cycle_core do
  namespace :clear do
    desc "Remove all data except for configuration data like users"
    task :all => :environment do
      DataCycleCore::Classification.destroy_all
      DataCycleCore::ClassificationAlias.destroy_all
      DataCycleCore::CreativeWork.destroy_all
      DataCycleCore::Event.destroy_all
      DataCycleCore::Person.destroy_all
      DataCycleCore::Place.destroy_all
    end

    desc "Remove all contents related data like creative works and places (does not remove classifications)"
    task :contents => :environment do
      DataCycleCore::CreativeWork.destroy_all
      DataCycleCore::Event.destroy_all
      DataCycleCore::Person.destroy_all
      DataCycleCore::Place.destroy_all
    end
  end

  namespace :import do
    desc "List available endpoints for import"
    task :list => :environment do
      DataCycleCore::ExternalSource.all.each do |external_source|
        puts "#{external_source.id} - #{external_source.name}"
      end
    end

    desc "Download and import data from given data source"
    task :perform, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = {max_count: FIXNUM_MAX}.merge(args.to_h)

      use_case = DataCycleCore::UseCase.find_by(external_source_id: options[:external_source_id])

      download_class = Object.const_get("DataCycleCore::#{use_case.external_source.config["download"]}")
      download_job = download_class.new(options[:external_source_id], false, 100, options[:max_count].to_i)
      download_job.download

      import_class = Object.const_get("DataCycleCore::#{use_case.external_source.config["import"]}")
      import_job = import_class.new(options[:external_source_id])
      import_job.import
    end    

    desc "Only download data from given data source"
    task :download, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = {max_count: FIXNUM_MAX}.merge(args.to_h)

      use_case = DataCycleCore::UseCase.find_by(external_source_id: options[:external_source_id])

      download_class = Object.const_get("DataCycleCore::#{use_case.external_source.config["download"]}")
      download_job = download_class.new(options[:external_source_id], false, 100, options[:max_count].to_i)
      download_job.download
    end

    desc "Only import (without downloading) data from given data source"
    task :import, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = {}.merge(args.to_h)

      use_case = DataCycleCore::UseCase.find_by(external_source_id: options[:external_source_id])

      import_class = Object.const_get("DataCycleCore::#{use_case.external_source.config["import"]}")
      import_job = import_class.new(options[:external_source_id])
      import_job.import
    end
  end
end
