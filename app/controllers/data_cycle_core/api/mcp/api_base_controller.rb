# frozen_string_literal: true

module DataCycleCore
  module Api
    module Mcp
      # Base of the GLOBAL MCP mount (Api::Mcp::McpController) -- auth and error handling analogous
      # to Api::V4::ApiBaseController, but without its endpoint scoping.
      #
      # NOT the base of both mounts: Api::V4::McpController does inherit from "ApiBaseController"
      # too, but there that resolves lexically to Api::V4::ApiBaseController. What the two mounts
      # share sits in modules (DataCycleCore::McpTransportConcern, DataCycleCore::Mcp::*) -- a
      # change here affects the global mount only.
      class ApiBaseController < ActionController::API
        include CanCan::ControllerAdditions
        include ActiveSupport::Rescuable
        include DataCycleCore::ErrorHandler
        include DataCycleCore::ApiBeforeActions

        # Ability of the current user, or nil without an authenticated user.
        def current_ability
          @current_ability ||= (current_user ? DataCycleCore::Ability.new(current_user, session) : nil)
        end
      end
    end
  end
end
