# frozen_string_literal: true

module DataCycleCore
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_permitted_parameters, if: :devise_controller?
    include DataCycleCore::ErrorHandler

    layout 'data_cycle_core/devise'
    HONEYPOT_FIELDS = [:user_full_name, :user_notes].freeze

    def create
      if sign_up_params.slice(*HONEYPOT_FIELDS).compact_blank.values.any?
        # set_flash_message! :notice, :signed_up
        redirect_to new_user_registration_path
        return
      end
      build_resource(sign_up_params)
      resource.save if valid_additional_attributes?(params.dig('user', 'additional_attributes'))

      yield resource if block_given?
      if resource.persisted?
        if resource.active_for_authentication?
          set_flash_message! :notice, :signed_up
          sign_up(resource_name, resource)
          respond_with resource, location: after_sign_up_path_for(resource)
        else
          set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
          expire_data_after_sign_in!
          respond_with resource, location: after_inactive_sign_up_path_for(resource)
        end

        DataCycleCore::Feature::UserRegistration.notify_users(resource) if DataCycleCore::Feature::UserRegistration.new_user_notification?
      else
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end
    end

    protected

    def configure_permitted_parameters
      update_attrs = [:given_name, :family_name, :name, {user_group_ids: [], additional_attributes: {}}] + HONEYPOT_FIELDS
      devise_parameter_sanitizer.permit :sign_up, keys: update_attrs
      devise_parameter_sanitizer.permit :account_update, keys: update_attrs
    end

    private

    def valid_additional_attributes?(additional_attributes)
      (DataCycleCore::Feature::UserRegistration.terms_conditions_url.blank? || additional_attributes&.key?('terms_conditions_at')) &&
        (DataCycleCore::Feature::UserRegistration.privacy_policy_url.blank? || additional_attributes&.key?('privacy_policy_at'))
    end
  end
end
