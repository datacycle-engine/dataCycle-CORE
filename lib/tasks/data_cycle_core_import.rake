# frozen_string_literal: true

# future additon in file dc.rake

namespace :data_cycle_core do
  namespace :import do
    desc 'List available endpoints for import'
    task list: :environment do
      DataCycleCore::ExternalSystem.where('external_systems.config ? :key', key: 'import_config').find_each do |external_source|
        puts "#{external_source.id} - #{external_source.name}"
      end
    end

    desc 'Download and import data from given data source'
    task :perform, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
      options = Hash[{}.merge(args.to_h).map do |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSystem.find(options[:external_source_id])
      external_source.download(options)
      external_source.import(options)
    end

    desc 'Only download data from given data source'
    task :download, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
      options = Hash[{}.merge(args.to_h).map do |k, v|
        if k == :max_count && v
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSystem.find(options[:external_source_id])
      external_source.download(options)
    end

    desc 'Only import (without downloading) data from given data source'
    task :import, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
      options = Hash[{}.merge(args.to_h).map do |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSystem.find(options[:external_source_id])
      external_source.import(options)
    end

    desc 'Import a specific data_set from a given source'
    task :import_one, [:external_source_id, :stage, :external_key, :mode] => [:environment] do |_, args|
      options = args.to_h.symbolize_keys
      external_source = DataCycleCore::ExternalSystem.find(options[:external_source_id])
      puts "importing from #{external_source.name} (#{external_source.id}) with external_key: #{options[:external_key]}"
      # puts 'Be aware that the data_set might not be updated if the data_hash detects that the old and the new data are the same!'
      external_source.import_one(options[:stage].to_sym, options[:external_key], {}, options[:mode] || 'full')
    end

    desc 'Download a specific data_set from a given source that supports it'
    task :download_one, [:external_source_id, :stage, :external_key] => [:environment] do |_, args|
      options = args.to_h.symbolize_keys
      external_source = DataCycleCore::ExternalSystem.find(options[:external_source_id])
      puts "downloading from #{external_source.name} (#{external_source.id}) with external_key: #{options[:external_key]}"
      external_source.download_single(options[:stage].to_sym, { external_keys: Array.wrap(options[:external_key]), mode: 'full' })
    end

    desc 'Download and import data from partial data source'
    task :perform_partial, [:external_source_id, :download_names, :import_names, :mode, :max_count] => [:environment] do |_, args|
      options = Hash[{}.merge(args.to_h).map do |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSystem.find(options[:external_source_id])
      options[:download_names].presence.split(',').each do |download_name|
        external_source.download_single(download_name.squish.to_sym, options)
      end
      options[:import_names].presence.split(',').each do |import_name|
        external_source.import_single(import_name.squish.to_sym, options)
      end
    end

    desc 'download data from partial data source'
    task :download_partial, [:external_source_id, :download_names, :mode, :max_count] => [:environment] do |_, args|
      options = Hash[{}.merge(args.to_h).map do |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSystem.find(options[:external_source_id])
      options[:download_names].presence.split(',').each do |download_name|
        external_source.download_single(download_name.squish.to_sym, options)
      end
    end

    desc 'import data from partial data source'
    task :import_partial, [:external_source_id, :import_names, :mode, :max_count] => [:environment] do |_, args|
      options = Hash[{}.merge(args.to_h).map do |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSystem.find(options[:external_source_id])
      options[:import_names].presence.split(',').each do |import_name|
        external_source.import_single(import_name.squish.to_sym, options)
      end
    end
  end
end
