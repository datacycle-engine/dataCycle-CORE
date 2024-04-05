# frozen_string_literal: true

module DataCycleCore
  class PermissionsController < ApplicationController
    authorize_resource

    def index
      @allowed_roles = DataCycleCore::Role.accessible_by(current_ability).order(rank: :asc)
      @permissions = Abilities::PermissionsList.grouped_list(@allowed_roles, current_ability)
    end
  end
end
