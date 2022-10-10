# frozen_string_literal: true

module DataCycleCore
  class EmailPasswordStrategy < Warden::Strategies::Base
    def valid?
      request.env['warden.force_strategy'] == :email_password && params[:email].present? && params[:password].present?
    end

    def authenticate!
      user = User.find_by(email: params[:email])
      params[:iss].presence&.then { |i| request.env['data_cycle.feature.user_api.issuer'] = i }
      params[:original_iss].presence&.then { |i| request.env['data_cycle.feature.user_api.issuer'] = i }
      user&.valid_password?(params[:password]) ? success!(user) : fail!('invalid combination of email and password')
    end

    def store?
      false
    end
  end
end
