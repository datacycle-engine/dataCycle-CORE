# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module PublicationSchedule
        def before_save_data_hash(options)
          super

          inherit_publication_attributes(data_hash: options.data_hash) if DataCycleCore::Feature::PublicationSchedule.available?(self) &&
                                                                          DataCycleCore.features.dig(:publication_schedule, :classification_keys).present? &&
                                                                          respond_to?(:publication_schedule)
        end

        private

        def inherit_publication_attributes(data_hash:)
          DataCycleCore.features.dig(:publication_schedule, :classification_keys).each do |key|
            data_hash[key] = data_hash.dig('publication_schedule')&.map { |p| p.key?('datahash') ? p.dig('datahash', key) : p[key] }&.flatten&.compact&.uniq
          end
        end
      end
    end
  end
end
