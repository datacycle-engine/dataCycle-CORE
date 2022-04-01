# frozen_string_literal: true

module DataCycleCore
  class GuestUserStrategy < Warden::Strategies::Base
    def valid?
      session[:guest_user_id].present?
    end

    def authenticate!
      u = DataCycleCore::User.find_by(id: session[:guest_user_id])

      return if u.nil?

      success!(u)
    end
  end
end
