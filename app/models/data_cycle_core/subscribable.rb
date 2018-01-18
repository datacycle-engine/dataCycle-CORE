module DataCycleCore
  module Subscribable
    extend ActiveSupport::Concern

    included do
      has_many :subscriptions, as: :subscribable, dependent: :destroy

      after_update :notify_subscribers, if: :changed?
    end

    def notify_subscribers
      self.subscriptions.each do |subscription|
        unless self.metadata['last_updated_by'] == subscription.user.id || subscription.user.notification_frequency != DataCycleCore.notification_frequencies[0]
          SubscriptionMailer.notify(subscription.user, [self]).deliver_later
        end
      end
    end
  end
end
