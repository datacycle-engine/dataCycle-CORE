# frozen_string_literal: true

module DataCycleCore
  module ErrorHandler
    extend ActiveSupport::Concern

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
        format.json { render status: :not_found, json: { "error": I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message, locale: DataCycleCore.ui_language) } }
        format.js { render status: :not_found, js: I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message, locale: DataCycleCore.ui_language) }
        format.any { head :not_found }
      end
    end

    def redirect_back_with_error(exception, status_code)
      exception_message = exception&.message&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      respond_to do |format|
        format.html { redirect_back fallback_location: authorized_root_path, alert: I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message, locale: DataCycleCore.ui_language), allow_other_host: false }
        format.json { render status: status_code, json: { error: I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message, locale: DataCycleCore.ui_language) } }
        format.js { render status: status_code, js: I18n.t("exceptions.#{exception.class.name.underscore}", default: exception_message, locale: DataCycleCore.ui_language) }
        format.any { head status_code }
      end
    end
  end
end
