# frozen_string_literal: true

module DataCycleCore
  class ExceptionsController < ApplicationController
    include DataCycleCore::ErrorHandler

    helper DataCycleCore::ExceptionHelper

    rescue_from StandardError, with: :internal_server_error_exception
    skip_before_action :verify_authenticity_token

    def not_found_exception
      not_found(request.env['action_dispatch.exception'])
    end

    def unprocessable_entity_exception
      unprocessable_entity(request.env['action_dispatch.exception'])
    end

    def internal_server_error_exception
      respond_to do |format|
        format.html { render status: :internal_server_error }
        format.json { render status: :internal_server_error, json: { errors: ['Internal Server Error'] } }
        format.js { render status: :internal_server_error, js: 'Internal Server Error' }
        format.any { head :internal_server_error }
      end
    end

    def unauthorized_exception
      render status: :unauthorized
    end

    # override current_user to catch ActiveRecord::NoDatabaseError and other DB Exceptions
    def current_user
      super
    rescue StandardError
      nil
    end
  end
end
