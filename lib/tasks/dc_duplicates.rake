# frozen_string_literal: true

namespace :dc do
  namespace :duplicates do
    desc 'Recreate Duplicate-Candidates'
    task recreate: :environment do
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      data_object = DataCycleCore::Thing.where(external_source_id: nil, external_key: nil).where.not(content_type: 'embedded')
      total_items = data_object.size

      puts "RECREATE Duplicate Candidates (#{total_items})"

      queue = DataCycleCore::WorkerPool.new(ActiveRecord::Base.connection_pool.size - 1)
      progress = ProgressBar.create(total: total_items, format: '%t |%w>%i| %a - %c/%C', title: 'Items')

      duplicate_count = 0
      data_object.find_each do |content|
        queue.append do
          duplicate_count += content.create_duplicate_candidates.to_i
          progress.increment
        end
      end

      queue.wait!

      puts "RECREATED Duplicate Candidates - #{duplicate_count} duplicates found"
    end

    desc 'Create Duplicate-Candidates from a StoredFilter'
    task :create_duplicates, [:stored_filter] => [:environment] do |_, args|
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?
      abort('A stored filter ID, or a stored filter Name has to be specified') if args.stored_filter.blank?

      stored_filter = DataCycleCore::StoredFilter.by_id_or_name(args.stored_filter).first

      abort("stored filter #{args.stored_filter} does not exist!") if stored_filter.nil?

      stored_filter.language = Array(I18n.available_locales).map(&:to_s)
      query = stored_filter.apply

      total_items = query.count
      puts "(RE)CREATE Duplicate Candidates (#{total_items})"

      progress = ProgressBar.create(total: total_items, format: '%t |%w>%i| %a - %c/%C', title: stored_filter.name.presence || 'Items')

      duplicate_counts = []
      queue = DataCycleCore::WorkerPool.new(ActiveRecord::Base.connection_pool.size - 1)

      query.query.find_each do |content|
        queue.append do
          duplicate_counts.push(content.create_duplicate_candidates.to_i)
          progress.increment
        end
      end

      queue.wait!

      puts "(RE)CREATED Duplicate Candidates - #{duplicate_counts.sum} duplicates found"
    end

    desc '(Re)Create Duplicate-Candidates from Endpoint (faster than create_duplicates)'
    task :recreate_duplicates, [:endpoint_id_or_slug] => [:environment] do |_, args|
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?
      abort('A stored filter ID, or a stored filter Name has to be specified') if args.endpoint_id_or_slug.blank?

      start_time = Time.zone.now
      stored_filter = DataCycleCore::StoredFilter.by_id_or_slug(args.endpoint_id_or_slug).first
      watch_list = DataCycleCore::WatchList.without_my_selection.by_id_or_slug(args.endpoint_id_or_slug).first if stored_filter.nil?

      abort("endpoint #{args.endpoint_id_or_slug} not found!") if stored_filter.nil? && watch_list.nil?

      if stored_filter.present?
        stored_filter.language = Array(I18n.available_locales).map(&:to_s)
        query = stored_filter.apply.query
      else
        query = watch_list.things
      end

      total_items = query.count
      puts "(RE)CREATE Duplicate Candidates (#{total_items})"

      duplicate_count = query.create_duplicate_candidates
      puts "(RE)CREATED Duplicate Candidates - #{duplicate_count} duplicates found (#{(Time.zone.now - start_time).round} sec)"
    end

    desc 'delete duplicates with <score> and above'
    task :delete_duplicates, [:min_score, :stored_filter_id, :dry_run] => [:environment] do |_, args|
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      dry_run = args.fetch(:dry_run, false)
      stored_filter_id = args.fetch(:stored_filter_id, nil)
      score = args.fetch(:min_score, nil)&.to_i

      stored_filter = stored_filter_id.present? ? DataCycleCore::StoredFilter.find(stored_filter_id) : DataCycleCore::StoredFilter.new
      stored_filter.language = Array(I18n.available_locales).map(&:to_s)
      query = stored_filter.apply
      query = query.duplicate_candidates(true, score)

      items = query.all
      puts "Started merging #{items.size} duplicates\n"

      items.find_each do |item|
        next if dry_run

        duplicates = (item.duplicate_candidates.where('score >= ?', score).duplicates + [item]).sort_by { |v| [v.try(:width), v.try(:updated_at)] }
        original = duplicates.pop

        duplicates.each do |duplicate|
          original.merge_with_duplicate_and_version(duplicate)
          print '.'
        end
      end

      puts "\nFinished merging duplicates"

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end
    end

    desc 'consolidate duplicates with <score> and above for external_source_id'
    task :merge_duplicates, [:min_score, :stored_filter_id, :filter_duplicates, :dry_run] => [:environment] do |_, args|
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      filter_duplicates = args.fetch(:filter_duplicates, false)
      dry_run = args.fetch(:dry_run, false)
      stored_filter_id = args.fetch(:stored_filter_id, nil)
      score = args.fetch(:min_score, nil)&.to_i

      stored_filter = stored_filter_id.present? ? DataCycleCore::StoredFilter.find(stored_filter_id) : DataCycleCore::StoredFilter.new
      stored_filter.language = Array(I18n.available_locales).map(&:to_s)
      query_sf = stored_filter.apply
      query = query_sf.duplicate_candidates(true, score)

      items = query.all
      puts "Started merging #{items.size} duplicates\n"

      items.find_each do |item|
        next if dry_run

        duplicates_query = item.duplicate_candidates.where('score >= ?', score).duplicates
        duplicates_query = duplicates_query.where(id: query_sf.select(:id)) if filter_duplicates

        duplicates = (duplicates_query + [item]).sort_by { |v| v.try(:updated_at) }
        original = duplicates.pop

        duplicates.each do |duplicate|
          original.merge_with_duplicate_and_version(duplicate)
          print '.'
        end
      end

      puts "\nFinished merging duplicates"

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end
    end

    desc 'merges duplicate into original'
    task :merge_duplicate, [:original, :duplicate] => [:environment] do |_, args|
      original_param = args.fetch(:original, nil)
      duplicate_param = args.fetch(:duplicate, nil)
      abort('orignal and duplicate parameters must be specified') if original_param.nil? || duplicate_param.nil?

      original = DataCycleCore::Thing.find(original_param)
      duplicate = DataCycleCore::Thing.find(duplicate_param)

      puts "Thing(#{original_param}) <--- Thing(#{duplicate_param})"

      original.merge_with_duplicate_and_version(duplicate)
    end
  end
end
