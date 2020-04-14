# frozen_string_literal: true

module DataCycleCore
  class RegistrationsController < Devise::RegistrationsController
    include DataCycleCore::ErrorHandler
    rescue_from ActionController::BadRequest, with: :bad_request

    # POST /resource
    def create
      build_resource(sign_up_params)
      resource.save if valid_additional_attributes?(params.dig('additional_attributes'))

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
      else
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end
    end

    private

    def valid_additional_attributes?(additional_attributes)
      additional_attributes
        .select { |k, _| I18n.t('user_registration.consents').keys.map(&:to_s).include?(k) }
        .as_json.values.all? { |v| v == '1' }
    end
  end
end
