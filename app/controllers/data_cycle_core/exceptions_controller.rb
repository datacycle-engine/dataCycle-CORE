# frozen_string_literal: true

module DataCycleCore
  class ExceptionsController < ApplicationController
    include DataCycleCore::ErrorHandler

    skip_before_action :verify_authenticity_token

    def not_found
      not_found_exception(request.env['action_dispatch.exception'])
    end

    def unprocessable_entity
      unprocessable_entity_exception(request.env['action_dispatch.exception'])
    end

    def internal_server_error
      respond_to do |format|
        format.html { render status: :internal_server_error }
        format.any { head :internal_server_error }
      end
    end

    def unauthorized
      render status: :unauthorized
    end
  end
end
