# frozen_string_literal: true

module DcTasks
  def self.legacy_task(key, *args)
    Rake::Task["data_cycle_core:import:#{key}"].invoke(*args)
    Rake::Task["data_cycle_core:import:#{key}"].reenable
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
      DcTasks.legacy_task('perform', *args)
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
  end
end
