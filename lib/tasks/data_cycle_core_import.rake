# frozen_string_literal: true

FIXNUM_MAX = (2**(0.size * 8 - 2) - 1)

namespace :data_cycle_core do
  namespace :import do
    desc 'List available endpoints for import'
    task list: :environment do
      DataCycleCore::ExternalSource.all.each do |external_source|
        puts "#{external_source.id} - #{external_source.name}"
      end
    end

    desc 'Download and import data from given data source'
    task :perform, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
      options = Hash[{ max_count: FIXNUM_MAX }.merge(args.to_h).map do |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.download(options)
      external_source.import(options)
    end

    desc 'DEBUG: Only download data from given data source'
    task :download, [:external_source_id, :max_count] => [:environment] do |_, args|
      options = Hash[{ max_count: nil }.merge(args.to_h).map do |k, v|
        if k == :max_count && v
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.download(options)
    end

    desc 'DEBUG: Only import (without downloading) data from given data source'
    task :import, [:external_source_id, :mode, :max_count] => [:environment] do |_, args|
      options = Hash[{ max_count: FIXNUM_MAX }.merge(args.to_h).map do |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.import(options)
    end
  end
end