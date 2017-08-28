module DataCycleCore
  module Subscribable
    extend ActiveSupport::Concern

    included do
      has_many :subscriptions, as: :subscribable, dependent: :destroy

      after_save :notify_subscribers
    end

    def notify_subscribers
      if self.changed?
        self.subscriptions.each do |subscription|
          SubscriptionMailer.notify(subscription.user, self).deliver_later
        end
      end
    end

  end
end
