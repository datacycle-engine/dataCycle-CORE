# frozen_string_literal: true

module DataCycleCore
  class EmailPasswordStrategy < BaseStrategy
    def valid?
      warden_strategy? && params[:email].present? && params[:password].present?
    end

    def authenticate!
      user = User.find_by(email: params[:email])
      params[:iss].presence&.then { |i| request.env['data_cycle.feature.user_api.issuer'] = i }
      params[:original_iss].presence&.then { |i| request.env['data_cycle.feature.user_api.issuer'] = i }

      return fail!('invalid combination of email and password') unless user
      return success!(user) if validate(user) { user.valid_password?(params[:password]) }

      fail!('invalid combination of email and password')
    end

    def store?
      false
    end
  end
end
