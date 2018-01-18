module DataCycleCore
  module Subscribable
    extend ActiveSupport::Concern

    included do
      has_many :subscriptions, as: :subscribable, dependent: :destroy

      after_update :notify_subscribers, if: :changed?
    end

    def notify_subscribers
      self.subscriptions.each do |subscription|
        SubscriptionMailer.notify(subscription.user, self).deliver_later unless !self.metadata['last_updated_by'].blank? && subscription.user.id == self.metadata['last_updated_by']
      end
    end
  end
end
