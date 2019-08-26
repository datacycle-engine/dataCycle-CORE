# frozen_string_literal: true

namespace :dc do
  namespace :duplicates do
    desc 'Recreate Duplicate-Candidates'
    task recreate: :environment do
      abort('Feature DuplicateCandidate has to be enabled!') unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      data_object = DataCycleCore::Thing.where(template: false, external_source_id: nil, external_key: nil).where.not(content_type: 'embedded')
      total_items = data_object.size

      puts "RECREATE Duplicate Candidates (#{total_items}) - (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

      duplicate_count = 0
      DataCycleCore::ProgressBarService.for_shell(total_items) do |pb|
        data_object.find_each do |content|
          pb.inc
          duplicate_count += content.create_duplicate_candidates&.size.to_i
        end
      end

      puts "RECREATED Duplicate Candidates - #{duplicate_count} duplicates found"
    end
  end
end
