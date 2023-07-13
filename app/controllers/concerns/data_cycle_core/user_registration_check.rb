# frozen_string_literal: true

module DataCycleCore
  module UserRegistrationCheck
    extend ActiveSupport::Concern

    included do
      prepend_before_action :check_updated_privacy_policy, if: :check_required?
      prepend_before_action :check_updated_terms_conditions, if: :check_required?
    end

    private

    def check_updated_privacy_policy
      return unless DataCycleCore::Feature::UserRegistration.privacy_policy_changed?(current_user&.additional_attributes&.dig('privacy_policy_at'))

      session[:return_to] = request.url if session[:return_to].blank?

      redirect_to(consent_users_path(type: 'privacy_policy')) && return
    end

    def check_updated_terms_conditions
      return unless DataCycleCore::Feature::UserRegistration.terms_conditions_changed?(current_user&.additional_attributes&.dig('terms_conditions_at'))

      session[:return_to] = request.url if session[:return_to].blank?

      redirect_to(consent_users_path(type: 'terms_conditions')) && return
    end

    def check_required?
      request.format.html? &&
        warden.authenticated? &&
        !action_name.end_with?('consent') &&
        !is_a?(DataCycleCore::StaticController)
    end
  end
end
