module DataCycleCore
  class UsersController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    load_and_authorize_resource         # from cancancan (authorize)
    before_action :set_user, only: [:edit, :update, :destroy, :unlock]

    layout 'data_cycle_core/creative_works_edit'

    def index
      authorize! :manage, DataCycleCore::User
      if current_user.role.rank > 1
        @users = DataCycleCore::User.includes(:role)
      else
        @users = DataCycleCore::User.where(locked_at: nil).includes(:role)
      end
    end

    def create_user
      @user = DataCycleCore::User.new(user_params)
      @user.external = false

      if @user.save
        flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Benutzer'
        redirect_back(fallback_location: root_path)
      else
        flash[:error] = @user.try(:errors).try(:first).try(:[], 1)
        redirect_back(fallback_location: root_path)
      end
    end

    def edit
      render layout: "data_cycle_core/watch_lists_edit"
    end

    def update
      authorize! :set_role, @user if user_params[:role_id]

      method = (current_user == @user && !user_params[:password].nil?) ? 'update_with_password' : 'update'

      if @user.send(method, user_params)
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Benutzer'

        bypass_sign_in(@user) if (current_user == @user && !user_params[:password].nil?)

        if Rails.env.development?
          redirect_to edit_user_path(@user)
        elsif can? :manage, DataCycleCore::User
          redirect_to users_path
        else
          redirect_to root_path
        end

      else
        render :edit
      end
    end

    def destroy
      @user.lock_access!

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Benutzer'
      redirect_to users_path
    end

    def unlock
      @user.unlock_access!

      flash[:success] = I18n.t :unlocked, scope: [:controllers, :success], data: 'Benutzer'
      redirect_to users_path
    end

    private
    def user_params
      allowed_params = [:email, :family_name, :given_name, :role_id, user_group_ids: []]
      allowed_params.push(:password, :password_confirmation, :current_password) unless params[:user][:password].blank? || params[:user][:password_confirmation].blank?
      params.require(:user).permit(allowed_params)
    end

    def set_user
      @user = DataCycleCore::User.find(params[:id])
    end

  end
end
