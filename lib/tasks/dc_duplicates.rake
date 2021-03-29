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
        duplicate_count += content.create_duplicate_candidates&.size.to_i
        progress.increment
      end

      puts "RECREATED Duplicate Candidates - #{duplicate_count} duplicates found"
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
  end
end
