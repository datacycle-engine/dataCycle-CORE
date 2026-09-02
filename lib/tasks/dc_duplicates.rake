# frozen_string_literal: true

require 'rake_helpers/cleanup_helper'

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

      # the workers share both counters, so plain += would lose increments between its read and write
      duplicate_count = Concurrent::AtomicFixnum.new(0)
      skipped = Concurrent::AtomicFixnum.new(0)
      data_object.find_each do |content|
        queue.append do
          # the candidate rows of a pair are shared by its two contents, so two workers can still
          # collide over the deletes of one pair - the recalculation is idempotent, so retry it
          succeeded = CleanupHelper.with_deadlock_retry(logger: Rails.logger, identifier: "Thing #{content.id}") do
            duplicate_count.increment(content.create_duplicate_candidates.to_i)
          end
          skipped.increment unless succeeded
          progress.increment
        end
      end

      queue.wait!

      puts "RECREATED Duplicate Candidates - #{duplicate_count.value} duplicates found#{", #{skipped.value} item(s) skipped after repeated deadlocks (see the Rails log for their ids)" if skipped.value.positive?}"
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

      duplicate_count = Concurrent::AtomicFixnum.new(0)
      skipped = Concurrent::AtomicFixnum.new(0)
      queue = DataCycleCore::WorkerPool.new
      progress = ProgressBar.create(
        total: total_items,
        title: "#{collection.name.presence || 'Items'} (#{queue.num_workers} workers)"
      )

      query.find_each do |content|
        queue.append do
          succeeded = CleanupHelper.with_deadlock_retry(logger:, identifier: "Thing #{content.id}") do
            duplicate_count.increment(content.create_duplicate_candidates.to_i)
          end
          skipped.increment unless succeeded
          progress.increment
        end
      end

      queue.wait!

      logger.info "(RE)CREATED Duplicate Candidates for ##{collection.id} - #{duplicate_count.value} duplicates found#{", #{skipped.value} item(s) skipped after repeated deadlocks" if skipped.value.positive?} (#{(Time.zone.now - start_time).round} sec)"
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
    task :merge_duplicates, [:min_score, :stored_filter_id_or_slug, :filter_duplicates, :duplicate_method, :same_external_source] => [:environment] do |_, args|
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      filter_duplicates = args.filter_duplicates.to_s == 'true'
      same_external_source = args.same_external_source.to_s == 'true'
      stored_filter_id_or_slug = args.stored_filter_id_or_slug
      duplicate_method = args.duplicate_method
      score = args.min_score&.to_i

      stored_filter = stored_filter_id_or_slug.present? ? DataCycleCore::StoredFilter.by_id_or_slug(stored_filter_id_or_slug).first : DataCycleCore::StoredFilter.new
      abort("Task merge_duplicates: Stored filter for slug or id : #{stored_filter_id_or_slug} was not found") if stored_filter.blank?
      stored_filter.language = Array(I18n.available_locales).map(&:to_s)
      query_sf = stored_filter.apply
      value = {
        'min' => score,
        'method' => duplicate_method
      }
      items = query_sf.duplicate_candidate_filter(value).query
      logger = Logger.new('log/merge_duplicates.log')
      logger.info "Started merging #{items.size} duplicates\n"
      collect_duplicates = lambda do |item|
        relation = item.duplicate_candidates
        relation = relation.where(score: score..) if score.present?
        relation = relation.where(duplicate_method:) if duplicate_method.present?
        relation = relation.duplicates
        relation = relation.where(id: query_sf.select(:id)) if filter_duplicates
        relation = relation.where(external_source_id: item.external_source_id) if same_external_source
        relation
      end

      items.find_each do |item|
        candidates = (collect_duplicates.call(item) + [item])
          .sort_by { |v| [v.try(:internal_content_score).to_i, v.try(:updated_at)] }
        original = candidates.pop
        next if candidates.empty?

        logger.info "Start merging #{candidates.size} duplicates into #{original.external_key}"
        candidates.each { |duplicate| original.merge_with_duplicate_and_version(duplicate) }
        logger.info "Finished merging #{candidates.size} duplicates into #{original.external_key}"
      end

      logger.info 'Finished merging duplicates'
    end

    desc 'merge the duplicates listed in a csv/xlsx/ods file, needs dry_run=false to merge anything (columns "Original ID", "Duplikat ID" and "Status", where only Treffer and Mehrdeutig are merged)'
    task :merge_from_file, [:path, :dry_run, :skip_errors] => [:environment] do |_, args|
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?
      abort('A file path has to be specified') if args.path.blank?
      abort("File #{args.path} does not exist!") unless File.exist?(args.path)

      # a merge cannot be undone, so merging has to be asked for with dry_run=false. anything
      # else, a typo included, stays a dry run that only reports the plan.
      dry_run = !args.dry_run.to_s.casecmp?('false')
      skip_errors = args.skip_errors.to_s.casecmp?('true')
      logger = Logger.new('log/merge_duplicates_from_file.log')

      spreadsheet = DataCycleCore::Feature::DuplicateCandidate::MergeSpreadsheet.new(args.path)

      begin
        pairs = spreadsheet.call
      rescue StandardError => e
        message = "Could not read #{args.path}: #{e.message}"
        logger.error message
        abort(message)
      end

      plan = DataCycleCore::Feature::DuplicateCandidate::MergePlan.call(pairs)
      # the counts tell a misread status column apart from a correct one: taking a column of free
      # text for the status leaves almost no pair and skips nearly every row
      summary = "#{args.path}: #{pairs.size} pair(s), #{pairs.count(&:directed?)} of them naming their original, " \
                "#{spreadsheet.skipped_rows.size} row(s) without both ids and #{spreadsheet.skipped_status_rows.size} row(s) by status skipped, " \
                "#{plan.groups.size} group(s) (dry_run: #{dry_run}, skip_errors: #{skip_errors})"

      logger.info "Started merging duplicates from #{summary}"
      puts summary

      # the locations, so that a half-filled file can be fixed without reopening it
      logger.info "Rows without both ids: #{spreadsheet.skipped_rows.join(', ')}" if spreadsheet.skipped_rows.present?
      logger.info "Rows skipped by status: #{spreadsheet.skipped_status_rows.join(', ')}" if spreadsheet.skipped_status_rows.present?

      # the errors stop a merging run unless it is told to skip them
      blocked_by_errors = plan.errors.present? && !skip_errors

      if plan.errors.present?
        plan.errors.each { |error| logger.error error }

        message = "#{plan.errors.size} error(s) in #{args.path}, see log/merge_duplicates_from_file.log."

        # a dry run reports the whole plan instead of stopping here, so that one run lists every
        # error of the file and the groups that would be left
        if blocked_by_errors && !dry_run
          logger.error "Aborted without merging: #{message}"
          abort("#{message} Nothing was merged, rerun with skip_errors=true to merge the #{plan.valid_groups.size} valid group(s).")
        end

        notice = if skip_errors
                   "#{message} Skipping #{plan.invalid_groups.size} group(s) with errors"
                 else
                   "#{message} They affect #{plan.invalid_groups.size} group(s)."
                 end

        logger.warn notice
        puts notice
      end

      # blocked_by_errors is only ever true here in a dry run, a merging run has aborted above.
      # those groups are listed for the report but no run would reach them as the file stands.
      prefix = if blocked_by_errors
                 '[blocked] '
               elsif dry_run
                 '[dry run] '
               end

      plan.valid_groups.each do |group|
        logger.info "#{prefix}Merging #{group.duplicates.size} duplicate(s): #{group}"
        next if dry_run

        group.merge!.each do |failure|
          if failure.reason == :locked
            # the merge is idempotent, so the job can finish it once the lock is gone
            logger.warn "#{failure.message}, scheduling MergeDuplicateJob"
            DataCycleCore::MergeDuplicateJob.perform_later(group.original.id, failure.duplicate.id)
          else
            # :refused should not happen, the plan checks up front what the core refuses
            logger.error "Could not merge #{failure.duplicate.id} into #{group.original.id}"
          end
        end
      end

      if dry_run
        # what the same run with dry_run=false would do, which is nothing as long as the errors
        # are neither fixed nor skipped
        result = if blocked_by_errors
                   "Dry run: no database changes made. A run with dry_run=false would abort on the #{plan.errors.size} error(s); " \
                     "with skip_errors=true it would merge #{plan.valid_groups.size} group(s)."
                 else
                   "Dry run: no database changes made, #{plan.valid_groups.size} group(s) would be merged. Rerun with dry_run=false to merge them."
                 end

        logger.info result
        puts result
      else
        logger.info "Finished merging #{plan.valid_groups.size} group(s)"
        puts "Finished merging #{plan.valid_groups.size} group(s)"
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
