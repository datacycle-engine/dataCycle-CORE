# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Releasable < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::Releasable
        end

        def data_hash_module
          DataCycleCore::Feature::DataHash::Releasable
        end

        def get_stage(stage = '')
          configuration.dig('classification_names', stage)
        end

        # The Release-Stati concept a stage names, which is what release_status_id holds.
        # @param stage [String] a key of the feature's classification_names
        # @return [String, nil] the concept id, nil when the stage or its concept is missing
        def stage_concept_id(stage)
          name = get_stage(stage)
          return if name.blank?

          DataCycleCore::Concept.joins(:concept_scheme)
            .find_by(name:, concept_schemes: { name: 'Release-Stati' })&.id
        end

        def send_reminder_email(data_links)
          return if data_links.nil?

          data_links.includes(:receiver).group_by(&:receiver).each do |receiver, links|
            next if receiver.nil?

            DataCycleCore::ReleasableSubscriptionMailer.remind_receiver(receiver, links.pluck(:id)).deliver_later
          end
        end
      end
    end
  end
end
