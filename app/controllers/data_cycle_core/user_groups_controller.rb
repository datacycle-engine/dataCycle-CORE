module DataCycleCore
  class UserGroupsController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    load_and_authorize_resource         # from cancancan (authorize)
    before_action :set_user_group, only: [:edit, :update, :destroy]

    layout 'data_cycle_core/creative_works_edit'

    def index
      authorize! :crud, DataCycleCore::UserGroup
      @user_groups = DataCycleCore::UserGroup.all
    end

    def create
      @user_group = DataCycleCore::UserGroup.new(user_group_params)

      if @user_group.save
        flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Benutzergruppe', locale: DataCycleCore.ui_language
        redirect_back(fallback_location: root_path)
      else
        flash[:error] = @user_group.try(:errors).try(:first).try(:[], 1)
        redirect_back(fallback_location: root_path)
      end
    end

    def edit
      render layout: "data_cycle_core/watch_lists_edit"
    end

    def update

      if @user_group.update_attributes(user_group_params)
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Benutzergruppe', locale: DataCycleCore.ui_language

        if Rails.env.development?
          redirect_to edit_user_group_path(@user_group)
        else
          redirect_to user_groups_path
        end

      else
        render 'edit'
      end
    end

    def destroy
      if @user_group.destroy
        flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Benutzergruppe', locale: DataCycleCore.ui_language
        redirect_back(fallback_location: root_path)
      else
        flash[:error] = @user_group.try(:errors).try(:first).try(:[], 1)
        redirect_back(fallback_location: root_path)
      end
    end

    private
    def user_group_params
      params.require(:user_group).permit(:name, user_ids: [], classification_ids: [])
    end

    def set_user_group
      @user_group = DataCycleCore::UserGroup.find(params[:id])
    end

  end
end
