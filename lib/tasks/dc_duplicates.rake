# frozen_string_literal: true

namespace :dc do
  namespace :duplicates do
    desc 'Recreate Duplicate-Candidates'
    task recreate: :environment do
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      data_object = DataCycleCore::Thing.where(template: false, external_source_id: nil, external_key: nil).where.not(content_type: 'embedded')
      total_items = data_object.size

      puts "RECREATE Duplicate Candidates (#{total_items})"

      progress = ProgressBar.create(total: total_items, format: '%t |%w>%i| %a - %c/%C', title: 'Items')

      duplicate_count = 0
      data_object.find_each do |content|
        duplicate_count += content.create_duplicate_candidates.to_i
        progress.increment
      end

      puts "RECREATED Duplicate Candidates - #{duplicate_count} duplicates found"
    end

    desc 'Create Duplicate-Candidates from a StoredFilter'
    task :create_duplicates, [:stored_filter] => [:environment] do |_, args|
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      filter_param = args.fetch(:stored_filter, nil)
      abort('A stored filter ID, or a stored filter Name has to be specified') if filter_param.blank?

      stored_filter = DataCycleCore::StoredFilter.find_by(id: filter_param)
      stored_filter = DataCycleCore::StoredFilter.find_by(name: filter_param) if stored_filter.blank?
      abort("stored filter #{filter_param} does not exist!") if stored_filter.blank?

      stored_filter.language = Array(I18n.available_locales).map(&:to_s)
      query = stored_filter.apply

      total_items = query.count
      puts "(RE)CREATE Duplicate Candidates (#{total_items})"

      progress = ProgressBar.create(total: total_items, format: '%t |%w>%i| %a - %c/%C', title: 'Items')

      duplicate_count = 0
      pool = Concurrent::FixedThreadPool.new(ActiveRecord::Base.connection_pool.size - 1)
      futures = []

      query.query.find_each do |content|
        futures << Concurrent::Promise.execute({ executor: pool }) do
          ActiveRecord::Base.connection_pool.with_connection do
            duplicate_count += content.create_duplicate_candidates.to_i
            progress.increment
          end
        end
      end

      futures.each(&:wait!)

      puts "(RE)CREATED Duplicate Candidates - #{duplicate_count} duplicates found"
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
      progressbar = ProgressBar.create(total: items.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      items.find_each do |item|
        next(progressbar.increment) if dry_run

        duplicates = (item.duplicate_candidates.where('score >= ?', score).duplicates + [item]).sort_by { |v| [v.try(:width), v.try(:updated_at)] }
        original = duplicates.pop

        duplicates.each { |duplicate| original.merge_with_duplicate(duplicate) }

        progressbar.increment
      end

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end
    end

    desc 'consolidate duplicates with <score> and above'
    task :merge_duplicates, [:min_score, :stored_filter_id, :dry_run] => [:environment] do |_, args|
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      dry_run = args.fetch(:dry_run, false)
      stored_filter_id = args.fetch(:stored_filter_id, nil)
      score = args.fetch(:min_score, nil)&.to_i

      stored_filter = stored_filter_id.present? ? DataCycleCore::StoredFilter.find(stored_filter_id) : DataCycleCore::StoredFilter.new
      stored_filter.language = Array(I18n.available_locales).map(&:to_s)
      query = stored_filter.apply
      query = query.duplicate_candidates(true, score)

      items = query.all
      progressbar = ProgressBar.create(total: items.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      items.find_each do |item|
        next(progressbar.increment) if dry_run

        duplicates = (item.duplicate_candidates.where('score >= ?', score).duplicates + [item]).sort_by { |v| v.try(:updated_at) }
        original = duplicates.pop

        duplicates.each { |duplicate| original.merge_with_duplicate(duplicate) }

        progressbar.increment
      end

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
      DataCycleCore::MergeDuplicateJob.perform_later(original.id, duplicate.id)
    end
  end
end
