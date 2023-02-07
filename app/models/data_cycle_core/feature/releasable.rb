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
