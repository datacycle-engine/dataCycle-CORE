module DataCycleCore
  class UsersController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    load_and_authorize_resource         # from cancancan (authorize)

    layout 'data_cycle_core/creative_works_edit'

    def index
      @users = DataCycleCore::User.accessible_by(current_ability)
    end

    def show
      @user = DataCycleCore::User.find(params[:id])
    end

    def edit
      @user = DataCycleCore::User.find(params[:id])
      render layout: "data_cycle_core/watch_lists_edit"
    end

    def update
      @user = DataCycleCore::User.find(params[:id])
      authorize! :set_role, @user if user_params[:role]

      if @user.update(user_params) # update_with_password for passwordchange
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'User'

        if Rails.env.development?
          redirect_to edit_user_path(@user) if Rails.env.development?
        else
          redirect_to user_path(@user, trail: session[:trail])
        end

      else
        render 'edit'
      end
    end

    def destroy
      @user = DataCycleCore::User.find(params[:id])
      @user.destroy

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'User'
      redirect_back(fallback_location: root_path)
    end

    private
      def user_params
        params.require(:user).permit(:email, :family_name, :given_name, :password, :password_confirmation, :current_password, :role)
      end

  end
end
