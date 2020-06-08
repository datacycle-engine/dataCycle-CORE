# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module PublicationSchedule
        def self.prepended(base)
          base.before_save_data_hash :inherit_publication_attributes, if: proc {
            DataCycleCore::Feature::PublicationSchedule.available?(self) &&
              DataCycleCore.features.dig(:publication_schedule, :classification_keys).present? &&
              respond_to?('publication_schedule')
          }
        end

        def inherit_publication_attributes
          DataCycleCore.features.dig(:publication_schedule, :classification_keys).each do |key|
            @data_hash[key] = @data_hash.dig('publication_schedule')&.map { |p| p[key] }&.flatten&.compact&.uniq if @data_hash.dig('publication_schedule').present?
          end
        end
      end
    end
  end
end
