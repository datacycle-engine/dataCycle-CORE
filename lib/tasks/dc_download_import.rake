# frozen_string_literal: true

require 'rake_helpers/import_helper'

namespace :dc do
  desc 'Only import (without downloading) data from given data source'
  task :import, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
    ImportHelper.legacy_task('import', *args)
  end

  desc 'Only download data from given data source'
  task :download, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
    ImportHelper.legacy_task('download', *args)
  end

  desc 'Download and import data from given data source'
  task :downport, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
    ImportHelper.legacy_task('perform', *args)
  end

  namespace :downport do
    desc 'List available endpoints for import'
    task list: :environment do
      ImportHelper.legacy_task('list')
    end

    desc 'Download and import data from partial data source'
    task :partial, [:external_source_id, :download_names, :import_names, :mode, :max_count] => [:environment] do |_, args|
      ImportHelper.legacy_task('perform_partial', *args)
    end

    desc 'perform download and import data for specific credential from feratel data source. Delimiter is | for multiple download_names and import_names'
    task :by_cred, [:external_source_id, :credential_key, :download_names, :import_names, :mode, :max_count] => [:environment] do |_, args|
      # options = convert_args_to_options(args)
      options = ImportHelper.convert_args_to_options(args)

      raise 'Error: credential_key is required!' if options[:credential_key].nil?

      ImportHelper.download_by_cred(args)
      ImportHelper.import_by_cred(args)
    end
  end

  namespace :import do
    desc 'Import a specific data_set from a given source'
    task :one, [:external_source_id, :stage, :external_key, :mode] => [:environment] do |_, args|
      ImportHelper.legacy_task('import_one', *args)
    end

    desc 'import data from partial data source'
    task :partial, [:external_source_id, :import_names, :mode, :max_count] => [:environment] do |_, args|
      ImportHelper.legacy_task('import_partial', *args)
    end

    desc 'import data for specific credential from partial data source. Delimiter is | for multiple import_names'
    task :partial_by_cred, [:external_source_id, :credential_key, :import_names, :mode, :max_count] => [:environment] do |_, args|
      raise 'Import names are required!' if args[:import_names].nil?

      ImportHelper.import_by_cred(args)
    end

    desc 'import data for specific credential from partial data source. Delimiter is | for multiple import_names'
    task :by_cred, [:external_source_id, :credential_key, :mode, :max_count] => [:environment] do |_, args|
      ImportHelper.import_by_cred(args)
    end
  end

  namespace :download do
    desc 'Download a specific data_set from a given source that supports it'
    task :one, [:external_source_id, :stage, :external_key] => [:environment] do |_, args|
      ImportHelper.legacy_task('download_one', *args)
    end

    desc 'download data from partial data source'
    task :partial, [:external_source_id, :download_names, :mode, :max_count] => [:environment] do |_, args|
      ImportHelper.legacy_task('download_partial', *args)
    end

    desc 'Only download data from given data source.'
    task :by_cred, [:external_source_id, :credential_key, :mode, :max_count] => [:environment] do |_, args|
      ImportHelper.download_by_cred(args)
    end

    desc 'Partial download by credential key for a specific data source. Delimiter is | for multiple download_names'
    task :partial_by_cred, [:external_source_id, :credential_key, :download_names, :mode, :max_count] => [:environment] do |_, args|
      raise 'Download names are required!' if args[:download_names].nil?

      ImportHelper.download_by_cred(args)
    end
  end
end
