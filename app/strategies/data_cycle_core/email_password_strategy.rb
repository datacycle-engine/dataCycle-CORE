# frozen_string_literal: true

module DataCycleCore
  class EmailPasswordStrategy < BaseStrategy
    # every rejection but a lockout keeps this exact wording: API clients match on the string
    INVALID_CREDENTIALS_MESSAGE = 'invalid combination of email and password'
    LOCKED_MESSAGE = 'account_locked'

    def valid?
      warden_strategy? && params[:email].present? && params[:password].present?
    end

    def authenticate!
      user = User.find_by(email: params[:email])
      params[:iss].presence&.then { |i| request.env['data_cycle.feature.user_api.issuer'] = i }
      params[:original_iss].presence&.then { |i| request.env['data_cycle.feature.user_api.issuer'] = i }

      return fail!(INVALID_CREDENTIALS_MESSAGE) unless user
      return success!(user) if validate(user) { user.valid_password?(params[:password]) }

      # #validate already failed with devise's reason. A lockout has to survive as its own message -
      # reported as invalid credentials it is indistinguishable from a typo, so the user keeps
      # retrying and every attempt feeds the throttle that locked them out in the first place.
      fail!(message == :locked ? LOCKED_MESSAGE : INVALID_CREDENTIALS_MESSAGE)
    end

    def store?
      false
    end
  end
end
