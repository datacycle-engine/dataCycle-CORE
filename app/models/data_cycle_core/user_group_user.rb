# frozen_string_literal: true

module DataCycleCore
  class UserGroupUser < ApplicationRecord
    belongs_to :user
    belongs_to :user_group, touch: true

    after_create :notify_unlocked_users, if: -> { DataCycleCore::Feature::UserApi.enabled? && DataCycleCore::Feature::UserApi.new_user_confirmation? }

    private

    def notify_unlocked_users(_new_user = nil)
      issuer = DataCycleCore::Feature::UserApi.new_user_confirmations_issuer(user_group.name)

      return if issuer.blank?

      user.user_api_feature.current_issuer = issuer
      user.user_api_feature.notify_confirmed_user
    end
  end
end
