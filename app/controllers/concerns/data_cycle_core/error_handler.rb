# frozen_string_literal: true

module DataCycleCore
  module ErrorHandler
    extend ActiveSupport::Concern

    included do
      unless Rails.env.development?
        rescue_from CanCan::AccessDenied, with: :unauthorized
        rescue_from ActiveRecord::RecordNotFound, with: :not_found
        rescue_from ActionController::UnknownFormat, with: :not_acceptable
        rescue_from ActionController::InvalidAuthenticityToken, with: :unprocessable_entity
        rescue_from ActionController::BadRequest, with: :bad_request
        rescue_from ActiveRecord::RecordNotUnique, with: :conflict
        rescue_from DataCycleCore::Error::Filter::DateFilterRangeError, with: :stored_filter_error
        rescue_from DataCycleCore::Error::Filter::FilterRecursionError, with: :stored_filter_error
        rescue_from PG::StatementTooComplex, with: :bad_request
      end

      rescue_from DataCycleCore::Error::Api::TimeOutError, with: :too_many_requests
      rescue_from PG::QueryCanceled, with: :too_many_requests
      rescue_from DataCycleCore::Error::Api::BadRequestError, with: :bad_request_api_error
      rescue_from DataCycleCore::Error::Api::ExpiredContentError, with: :expired_content_api_error

      rescue_from DataCycleCore::Error::Download::InvalidSerializationFormatError, with: :user_interface_error
      rescue_from DataCycleCore::Error::Download::SerializationError, with: :user_interface_error
    end

    private

    def forbidden(exception)
      redirect_to_root_with_error exception, :forbidden
    end

    def unauthorized(exception)
      redirect_to_root_with_error exception, :unauthorized
    end

    def unprocessable_entity(exception)
      redirect_to_root_with_error exception, :unprocessable_entity
    end

    def bad_request_api_error(exception)
      api_errors = exception.data.map do |error|
        {
          source: {
            parameter: error[:parameter_path]
          },
          title: I18n.t("exceptions.#{exception.class.name.underscore}.#{error[:type]}", default: exception.message, locale: :en),
          detail: error[:detail]
        }
      end
      render json: { errors: api_errors }, layout: false, status: :bad_request
    end

    def expired_content_api_error(exception)
      api_errors = exception.data.map do |error|
        {
          source: {
            pointer: error[:pointer_path]
          },
          title: I18n.t("exceptions.#{exception.class.name.underscore}.#{error[:type]}", default: exception.message, locale: :en),
          detail: error[:detail]
        }
      end
      render json: { errors: api_errors }, layout: false, status: :not_found
    end

    def content_api_error(exception)
      [
        {
          source: {
            pointer: request.env['action_dispatch.original_path'] || request.path
          },
          detail: I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message(exception), locale: :en)
        }
      ]
    end

    def user_interface_error(exception)
      redirect_back(fallback_location: root_path, alert: I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message(exception), locale: helpers.active_ui_locale), allow_other_host: false) && return if is_a?(ApplicationController)

      bad_request
    end

    def not_acceptable
      head :not_acceptable
    end

    def bad_request
      head :bad_request
    end

    def too_many_requests
      head :too_many_requests, { 'Retry-After': 60 }
    end

    def not_found(exception)
      respond_to do |format|
        format.html { render 'data_cycle_core/exceptions/not_found_exception', status: :not_found } if is_a?(ApplicationController)
        format.json { render status: :not_found, json: { errors: content_api_error(exception) } }
        format.js { render status: :not_found, js: "console.warn('#{I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message(exception), locale: helpers.active_ui_locale)}')" } if is_a?(ApplicationController)
        format.any { head :not_found }
      end
    end

    def conflict(exception)
      respond_to do |format|
        format.html { render 'data_cycle_core/exceptions/conflict_exception', status: :conflict } if is_a?(ApplicationController)
        format.json { render status: :conflict, json: { errors: content_api_error(exception) } }
        format.js { render status: :conflict, js: "console.warn('#{I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message(exception), locale: helpers.active_ui_locale)}')" } if is_a?(ApplicationController)
        format.any { head :conflict }
      end
    end

    def redirect_to_root_with_error(exception, status_code, root_path_params = {})
      respond_to do |format|
        format.html { redirect_to authorized_root_path(nil, root_path_params), alert: I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message(exception), locale: helpers.active_ui_locale), allow_other_host: false } if is_a?(ApplicationController)
        format.json { render status: status_code, json: { errors: content_api_error(exception) } }
        format.js { render status: status_code, js: "console.error('#{I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message(exception), locale: helpers.active_ui_locale)}')" } if is_a?(ApplicationController)
        format.any { head status_code }
      end
    end

    def stored_filter_error(exception)
      redirect_to_root_with_error(exception, :bad_request, { reset: true })
    end

    def exception_message(exception)
      exception&.message&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    end
  end
end
