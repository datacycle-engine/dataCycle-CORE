# frozen_string_literal: true

module DataCycleCore
  class Subscription < ApplicationRecord
    belongs_to :user
    belongs_to :subscribable, polymorphic: true

    scope :by_user, ->(user) { where(user_id: user.id) }

    def self.except_user_id(user_id)
      where.not(user_id:)
    end

    def self.things
      return DataCycleCore::Thing.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::Thing.where(id: select(:subscribable_id))
    end

    def self.users
      return DataCycleCore::User.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::User.where(id: select(:user_id))
    end

    def self.to_notify(frequencies = ['always'])
      return if DataCycleCore.notification_frequencies.blank?

      includes(:user).where(users: { notification_frequency: frequencies, locked_at: nil })
    end
  end
end
