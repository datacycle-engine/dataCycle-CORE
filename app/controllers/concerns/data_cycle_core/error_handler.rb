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
      end

      rescue_from DataCycleCore::Error::Api::TimeOutError, with: :too_many_requests
      rescue_from DataCycleCore::Error::Api::BadRequestError, with: :bad_request_api_error
      rescue_from DataCycleCore::Error::Api::ExpiredContentError, with: :expired_content_api_error
    end

    private

    def forbidden(exception)
      redirect_back_with_error exception, :forbidden
    end

    def unauthorized(exception)
      redirect_back_with_error exception, :unauthorized
    end

    def unprocessable_entity(exception)
      redirect_back_with_error exception, :unprocessable_entity
    end

    def bad_request_api_error(exception)
      api_errors = exception.data.map do |error|
        {
          source: {
            parameter: error.dig(:parameter_path)
          },
          title: I18n.t("exceptions.#{exception.class.name.underscore}.#{error.dig(:type)}", default: exception.message, locale: :en),
          detail: error.dig(:detail)
        }
      end
      render json: { errors: api_errors }, layout: false, status: :bad_request
    end

    def expired_content_api_error(exception)
      api_errors = exception.data.map do |error|
        {
          source: {
            pointer: error.dig(:pointer_path)
          },
          title: I18n.t("exceptions.#{exception.class.name.underscore}.#{error.dig(:type)}", default: exception.message, locale: :en),
          detail: error.dig(:detail)
        }
      end
      render json: { errors: api_errors }, layout: false, status: :not_found
    end

    def content_api_error(exception)
      exception_message = exception&.message&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      [
        {
          source: {
            pointer: request.path
          },
          detail: I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message, locale: :en)
        }
      ]
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
      exception_message = exception&.message&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      respond_to do |format|
        format.html { render file: Rails.root.join('public', '404'), layout: false, status: :not_found }
        format.json { render status: :not_found, json: { errors: content_api_error(exception) } }
        format.js { render status: :not_found, js: I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message, locale: DataCycleCore.ui_language) }
        format.any { head :not_found }
      end
    end

    def redirect_back_with_error(exception, status_code)
      exception_message = exception&.message&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      respond_to do |format|
        format.html { redirect_to authorized_root_path, alert: I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message, locale: DataCycleCore.ui_language), allow_other_host: false }
        format.json { render status: status_code, json: { errors: content_api_error(exception) } }
        format.js { render status: status_code, js: "console.error('#{I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message, locale: DataCycleCore.ui_language)}')" }
        format.any { head status_code }
      end
    end
  end
end
