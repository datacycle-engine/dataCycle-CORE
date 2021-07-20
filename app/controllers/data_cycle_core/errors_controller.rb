# frozen_string_literal: true

module DataCycleCore
  class ErrorsController < ApplicationController
    def not_found
      render status: :not_found
    end

    def unacceptable
      render status: :unprocessable_entity
    end

    def internal_server_error
      render status: :internal_server_error
    end
  end
end
