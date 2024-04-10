# frozen_string_literal: true

PREFIX = 'data_cycle_core:import'

module DownportTasks
  def self.list
    Rake::Task["#{PREFIX}:list"].invoke
    Rake::Task["#{PREFIX}:list"].reenable
  end

  def self.dowload_import(*args)
    Rake::Task["#{PREFIX}:perform"].invoke(*args)
    Rake::Task["#{PREFIX}:perform"].reenable
  end
end

module ImportTasks
  def self.import(*args)
    Rake::Task["#{PREFIX}:import"].invoke(*args)
    Rake::Task["#{PREFIX}:import"].reenable
  end

  def self.import_one(*args)
    Rake::Task["#{PREFIX}:import_one"].invoke(*args)
    Rake::Task["#{PREFIX}:import_one"].reenable
  end

  def self.import_partial(*args)
    Rake::Task["#{PREFIX}:import_partial"].invoke(*args)
    Rake::Task["#{PREFIX}:import_partial"].reenable
  end
end

module DownloadTasks
  def self.download(*args)
    Rake::Task["#{PREFIX}:download"].invoke(*args)
    Rake::Task["#{PREFIX}:download"].reenable
  end

  def self.download_one(*args)
    Rake::Task["#{PREFIX}:download_one"].invoke(*args)
    Rake::Task["#{PREFIX}:download_one"].reenable
  end

  def self.download_partial(*args)
    Rake::Task["#{PREFIX}:download_partial"].invoke(*args)
    Rake::Task["#{PREFIX}:download_partial"].reenable
  end
end

namespace :dc do
  desc 'Only import (without downloading) data from given data source'
  task :import, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
    ImportTasks.import(*args)
  end

  desc 'Only download data from given data source'
  task :download, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
    DownloadTasks.download(*args)
  end

  desc 'Download and import data from given data source'
  task :downport, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
    DownportTasks.dowload_import(*args)
  end

  namespace :downport do
    desc 'List available endpoints for import'
    task list: :environment do
      DownportTasks.list
    end

    desc 'Download and import data from partial data source'
    task :partial, [:external_source_id, :download_names, :import_names, :mode, :max_count] => [:environment] do |_, args|
      DownportTasks.dowload_import(*args)
    end
  end

  namespace :import do
    desc 'Import a specific data_set from a given source'
    task :one, [:external_source_id, :stage, :external_key, :mode] => [:environment] do |_, args|
      ImportTasks.import_one(*args)
    end

    desc 'import data from partial data source'
    task :partial, [:external_source_id, :import_names, :mode, :max_count] => [:environment] do |_, args|
      ImportTasks.import_partial(*args)
    end
  end

  namespace :download do
    desc 'Download a specific data_set from a given source that supports it'
    task :one, [:external_source_id, :stage, :external_key] => [:environment] do |_, args|
      DownloadTasks.download_one(*args)
    end

    desc 'download data from partial data source'
    task :partial, [:external_source_id, :download_names, :mode, :max_count] => [:environment] do |_, args|
      DownloadTasks.download_partial(*args)
    end
  end
end
