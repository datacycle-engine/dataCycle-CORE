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

    # This method and service_unavailable_exception are both reached mid-action - by
    # rescue_from StandardError, and by the diversion on the next line - so each html branch
    # names its template rather than let an implicit render resolve action_name: a stale process
    # would otherwise answer /500 with a 503 status carrying the 500 page, and a failure inside
    # not_found_exception would answer 500 with the 404 page.
    def internal_server_error_exception
      return service_unavailable_exception if render_maintenance_page?

      respond_to do |format|
        format.html { render 'data_cycle_core/exceptions/internal_server_error_exception', status: :internal_server_error }
        format.json { render status: :internal_server_error, json: { errors: ['Internal Server Error'] } }
        format.js { render status: :internal_server_error, js: 'Internal Server Error' }
        format.any { head :internal_server_error }
      end
    end

    # Where the process trails the database, the failure belongs to the deploy and not to the
    # request: 503 tells a client to come back, and keeps a crawler from recording the outage
    # as a broken page.
    def service_unavailable_exception
      response.set_header('Retry-After', DataCycleCore::StaleProcess::RETRY_AFTER.to_s)

      respond_to do |format|
        format.html { render 'data_cycle_core/exceptions/service_unavailable_exception', status: :service_unavailable }
        format.json { render status: :service_unavailable, json: { errors: ['Service Unavailable'] } }
        format.js { render status: :service_unavailable, js: 'Service Unavailable' }
        format.any { head :service_unavailable }
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

    private

    # Decides once per request, and answers false afterwards: rescue_from StandardError sends
    # a failure inside service_unavailable_exception back to internal_server_error_exception,
    # which would otherwise hand it straight back to the action that just raised.
    def render_maintenance_page?
      return false if @maintenance_page_decided

      @maintenance_page_decided = true
      DataCycleCore::StaleProcess.stale?
    end
  end
end
