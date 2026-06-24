# frozen_string_literal: true

module DataCycleCore
  class GuestUserStrategy < BaseStrategy
    def valid?
      valid_strategy? && session[:guest_user_id].present?
    end

    def authenticate!
      u = DataCycleCore::User.find_by(id: session[:guest_user_id])

      return if u.nil?

      success!(u) if validate(u)

      fail!('invalid guest user')
    end
  end
end
