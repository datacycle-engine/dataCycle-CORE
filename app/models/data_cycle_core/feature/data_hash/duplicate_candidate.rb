# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module DuplicateCandidate
        extend ActiveSupport::Concern

        def after_save_data_hash(options)
          super

          # add job to check for possible duplicates and add them as duplicate_candidates
          add_check_for_duplicates_job if options.new_content &&
                                          options.check_for_duplicates &&
                                          !embedded? &&
                                          duplicate_method?
        end

        def create_duplicate_candidates
          duplicates = duplicate_method

          duplicate_candidates.with_fp.where.not(duplicate_id: duplicates&.pluck(:thing_duplicate_id)&.compact).thing_duplicates.delete_all

          timestamp = Time.zone.now

          duplicates.present? ? DataCycleCore::ThingDuplicate.insert_all(duplicates.each { |v| v.merge!({ thing_id: id, created_at: timestamp, updated_at: timestamp }) }, unique_by: :unique_thing_duplicate_idx).count : 0
        end

        def merge_with_duplicate_and_version(duplicate)
          I18n.with_locale(first_available_locale) do
            duplicate.original_id = id
            set_data_hash(data_hash: {}, version_name: DataCycleCore::Feature::DuplicateCandidate.version_name_for_merge(duplicate), force_update: true)
          end

          merge_with_duplicate(duplicate)
        end

        def merge_with_duplicate(duplicate)
          DataCycleCore::MergeDuplicateJob.perform_later(id, duplicate.id)

          DataCycleCore::Thing.find_by(id: duplicate.id)&.duplicate_candidates&.thing_duplicates&.delete_all
        end

        module ClassMethods
          def create_duplicate_candidates
            duplicates = DataCycleCore::Feature::DuplicateCandidate.find_duplicates_for_contents(all)
            all.duplicate_candidates.with_fp.where.not(duplicate_id: duplicates&.pluck(:thing_duplicate_id)&.compact).thing_duplicates.delete_all

            timestamp = Time.zone.now

            DataCycleCore::ThingDuplicate.insert_all(duplicates.each { |v| v.merge!({ created_at: timestamp, updated_at: timestamp }) }, unique_by: :unique_thing_duplicate_idx) if duplicates.present?

            duplicates&.size || 0
          end
        end

        private

        def add_check_for_duplicates_job
          DataCycleCore::CheckForDuplicatesJob.perform_later(id)
        end
      end
    end
  end
end
