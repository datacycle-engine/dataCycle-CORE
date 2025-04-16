# frozen_string_literal: true

module DcTasks
  def self.legacy_task(key, *args)
    Rake::Task["data_cycle_core:import:#{key}"].invoke(*args)
    Rake::Task["data_cycle_core:import:#{key}"].reenable
  end
end

module TaskFunctions
  def self.convert_args_to_options(args)
    number_args = [:max_count, :min_count]
    {}.merge(args.to_h).to_h do |k, v|
      if number_args.include?(k)
        [k, v.to_i]
      else
        [k, v]
      end
    end
  end

  def self.import_by_cred(args)
    options = convert_args_to_options(args)
    raise 'Error: credential_key is required!' if options[:credential_key].nil?
    options[:import] ||= {}

    # not all collection have the external_system field. We want to import this data as well.
    options[:import][:source_filter] = {
      'external_system.credential_keys' => { '$in' => [nil, options[:credential_key]] }
    }

    external_source = DataCycleCore::ExternalSystem.find(options[:external_source_id])

    options[:import_names] = external_source.config['import_config'].sort_by { |_, config| config['sorting'] }.to_h.keys.join('|') if options[:import_names].nil?
    options[:import_names].presence.split('|').each do |import_name|
      external_source.import_single(import_name.squish.to_sym, options)
    end
  end

  def self.download_by_cred(args)
    options = convert_args_to_options(args)
    raise 'Error: credential_key is required!' if options[:credential_key].nil?

    external_source = DataCycleCore::ExternalSystem.by_names_identifiers_or_ids(options[:external_source_id]).first

    raise 'External source not found!' if external_source.nil?

    options[:skip_save] = true

    if options[:download_names].present?
      options[:download_names].split('|').each do |download_name|
        external_source.download_single(download_name.squish.to_sym, options)
      end
    else
      external_source.download(options)
    end
  end
end

namespace :dc do
  desc 'Only import (without downloading) data from given data source'
  task :import, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
    DcTasks.legacy_task('import', *args)
  end

  desc 'Only download data from given data source'
  task :download, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
    DcTasks.legacy_task('download', *args)
  end

  desc 'Download and import data from given data source'
  task :downport, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
    DcTasks.legacy_task('perform', *args)
  end

  namespace :downport do
    desc 'List available endpoints for import'
    task list: :environment do
      DcTasks.legacy_task('list')
    end

    desc 'Download and import data from partial data source'
    task :partial, [:external_source_id, :download_names, :import_names, :mode, :max_count] => [:environment] do |_, args|
      DcTasks.legacy_task('perform_partial', *args)
    end

    desc 'perform download and import data for specific credential from feratel data source. Delimiter is | for multiple download_names and import_names'
    task :by_cred, [:external_source_id, :credential_key, :download_names, :import_names, :mode, :max_count] => [:environment] do |_, args|
      # options = convert_args_to_options(args)
      options = TaskFunctions.convert_args_to_options(args)

      raise 'Error: credential_key is required!' if options[:credential_key].nil?

      TaskFunctions.download_by_cred(args)
      TaskFunctions.import_by_cred(args)
    end
  end

  namespace :import do
    desc 'Import a specific data_set from a given source'
    task :one, [:external_source_id, :stage, :external_key, :mode] => [:environment] do |_, args|
      DcTasks.legacy_task('import_one', *args)
    end

    desc 'import data from partial data source'
    task :partial, [:external_source_id, :import_names, :mode, :max_count] => [:environment] do |_, args|
      DcTasks.legacy_task('import_partial', *args)
    end

    desc 'import data for specific credential from partial data source. Delimiter is | for multiple import_names'
    task :partial_by_cred, [:external_source_id, :credential_key, :import_names, :mode, :max_count] => [:environment] do |_, args|
      raise 'Import names are required!' if args[:import_names].nil?
      TaskFunctions.import_by_cred(args)
    end

    desc 'import data for specific credential from partial data source. Delimiter is | for multiple import_names'
    task :by_cred, [:external_source_id, :credential_key, :mode, :max_count] => [:environment] do |_, args|
      TaskFunctions.import_by_cred(args)
    end
  end

  namespace :download do
    desc 'Download a specific data_set from a given source that supports it'
    task :one, [:external_source_id, :stage, :external_key] => [:environment] do |_, args|
      DcTasks.legacy_task('download_one', *args)
    end

    desc 'download data from partial data source'
    task :partial, [:external_source_id, :download_names, :mode, :max_count] => [:environment] do |_, args|
      DcTasks.legacy_task('download_partial', *args)
    end

    desc 'Only download data from given data source.'
    task :by_cred, [:external_source_id, :credential_key, :mode, :max_count] => [:environment] do |_, args|
      TaskFunctions.download_by_cred(args)
    end

    desc 'Partial download by credential key for a specific data source. Delimiter is | for multiple download_names'
    task :partial_by_cred, [:external_source_id, :credential_key, :download_names, :mode, :max_count] => [:environment] do |_, args|
      raise 'Download names are required!' if args[:download_names].nil?
      TaskFunctions.download_by_cred(args)
    end
  end
end
