# frozen_string_literal: true

module DataCycleCore
  class WatchListSubscriberNotificationJob < ApplicationJob
    queue_as :mailers
    queue_with_priority 10
    queue_with_reference_id -> { arguments[0].id.to_s }
    queue_with_reference_type -> { "#{self.class.name.demodulize.underscore}-#{arguments[3]}" }

    def perform(watch_list, current_user, content_ids, type)
      watch_list.subscriptions.except_user_id(current_user.id).users.find_each do |user|
        job = self.class.find_by_identifiers(reference_id: user.id, reference_type: 'subscription_mailer_notify_changed_watch_list_items', queue_name: 'mailers')

        changed_items = job&.arguments&.dig(3, :args, 1) || {}

        job&.destroy

        changed_items[watch_list.id] = [] unless changed_items.key?(watch_list.id)
        content_ids.each do |id|
          deleted = changed_items[watch_list.id].reject! { |item| item[:id] == id }
          changed_items[watch_list.id].push({ type:, id:, user_id: current_user.id }) if deleted.blank?
        end

        SubscriptionMailer.notify_changed_watch_list_items(user, changed_items).deliver_later(wait_until: delivery_time(user))
      end
    end

    private

    def delivery_time(user)
      Time.zone.now.try("end_of_#{user.notification_frequency}") || 5.minutes.from_now
    end
  end
end
