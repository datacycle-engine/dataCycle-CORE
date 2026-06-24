# frozen_string_literal: true

namespace :dc do
  namespace :duplicates do
    desc 'Recreate Duplicate-Candidates'
    task recreate: :environment do
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      data_object = DataCycleCore::Thing.where(external_source_id: nil, external_key: nil).where.not(content_type: 'embedded')
      total_items = data_object.size

      puts "RECREATE Duplicate Candidates (#{total_items})"

      queue = DataCycleCore::WorkerPool.new
      progress = ProgressBar.create(total: total_items, title: 'Items')

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
    task :create_duplicates, [:collection_id_slug_name] => [:environment] do |_, args|
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?
      abort('A stored filter ID, or a stored filter Name has to be specified') if args.collection_id_slug_name.blank?

      collection = DataCycleCore::Collection.by_id_name_slug(args.collection_id_slug_name).first
      abort("collection #{args.collection_id_slug_name} does not exist!") if collection.nil?

      start_time = Time.zone.now

      collection.language = Array.wrap(I18n.available_locales).map(&:to_s)
      query = collection.things
      total_items = query.count
      logger = Logger.new('log/create_duplicates.log')
      logger.info "(RE)CREATE Duplicate Candidates for ##{collection.id} (#{total_items})"

      duplicate_counts = []
      queue = DataCycleCore::WorkerPool.new
      progress = ProgressBar.create(
        total: total_items,
        title: "#{collection.name.presence || 'Items'} (#{queue.num_workers} workers)"
      )

      query.find_each do |content|
        queue.append do
          duplicate_counts.push(content.create_duplicate_candidates.to_i)
          progress.increment
        end
      end

      queue.wait!

      logger.info "(RE)CREATED Duplicate Candidates for ##{collection.id} - #{duplicate_counts.sum} duplicates found (#{(Time.zone.now - start_time).round} sec)"
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
      query = query.duplicate_candidate_filter({ 'min' => score })
      items = query.query

      puts "Started merging #{items.size} duplicates\n"

      items.find_each do |item|
        next if dry_run

        duplicates = (item.duplicate_candidates.where(score: score..).duplicates + [item]).sort_by { |v| [v.try(:width), v.try(:updated_at)] }
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
    task :merge_duplicates, [:min_score, :stored_filter_id_or_slug, :filter_duplicates, :duplicate_method] => [:environment] do |_, args|
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      filter_duplicates = args.filter_duplicates.to_s == 'true'
      stored_filter_id_or_slug = args.stored_filter_id_or_slug
      duplicate_method = args.duplicate_method
      score = args.min_score&.to_i

      stored_filter = stored_filter_id_or_slug.present? ? DataCycleCore::StoredFilter.by_id_or_slug(stored_filter_id_or_slug).first : DataCycleCore::StoredFilter.new
      stored_filter.language = Array(I18n.available_locales).map(&:to_s)
      query_sf = stored_filter.apply
      value = {
        'min' => score,
        'method' => duplicate_method
      }
      items = query_sf.duplicate_candidate_filter(value).query
      logger = Logger.new('log/create_duplicates.log')
      logger.info "Started merging #{items.size} duplicates\n"
      items.find_each do |item|
        duplicates_base = item.duplicate_candidates
        duplicates_base = duplicates_base.where(score: score..) if score.present?
        duplicates_base = duplicates_base.where(duplicate_method: duplicate_method) if duplicate_method.present?
        duplicates_query = duplicates_base.duplicates
        duplicates_query = duplicates_query.where(id: query_sf.select(:id)) if filter_duplicates

        duplicates = (duplicates_query + [item]).sort_by { |v| [v.try(:internal_content_score).to_i, v.try(:updated_at)] }
        original = duplicates.pop

        duplicates.each do |duplicate|
          original.merge_with_duplicate_and_version(duplicate)
          print '.'
        end
      end

      puts "\n"

      logger.info 'Finished merging duplicates'
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
