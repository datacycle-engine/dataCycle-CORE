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
  end
end
