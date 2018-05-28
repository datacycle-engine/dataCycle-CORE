# frozen_string_literal: true

module DataCycleCore
  class UsersController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource except: :search # from cancancan (authorize)
    before_action :set_user, only: [:edit, :update, :destroy, :unlock]

    def index
      if current_user.has_rank?(10)
        @paginateObject = DataCycleCore::User.includes(:role, :user_groups).order(:email).page(params[:page])
      else
        @paginateObject = DataCycleCore::User.where(locked_at: nil).includes(:role).order(:email).page(params[:page])
      end
    end

    def create_user
      @user = ('DataCycleCore::' + controller_name.singularize.classify).constantize.new(permitted_params)

      if @user.save
        flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Benutzer', locale: DataCycleCore.ui_language
      else
        flash[:error] = @user.try(:errors).try(:first).try(:[], 1)
      end
      redirect_back(fallback_location: root_path)
    end

    def edit
    end

    def update
      authorize! :set_role, @user if permitted_params[:role_id].present?
      authorize! :generate_access_token, @user if params.dig(:user, :access_token).present?

      method = current_user == @user && permitted_params[:password].present? ? 'update_with_password' : 'update'

      if params.dig(controller_name.singularize.to_sym, :access_token).present? && params.dig(controller_name.singularize.to_sym, :access_token) == '1' && @user.access_token.blank?
        @user.update(access_token: SecureRandom.hex)
      elsif params.dig(controller_name.singularize.to_sym, :access_token).present? && params.dig(controller_name.singularize.to_sym, :access_token) == '0'
        @user.update(access_token: nil)
      end

      if @user.send(method, permitted_params)
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Benutzer', locale: DataCycleCore.ui_language

        bypass_sign_in(@user) if current_user == @user && !permitted_params[:password].nil?

        if params[:user_settings]
          redirect_to(settings_path, notice: I18n.t(:updated_multiple, scope: [:controllers, :success], data: 'Benutzereinstellungen', locale: DataCycleCore.ui_language))
        elsif Rails.env.development?
          redirect_to edit_user_path(@user)
        elsif can? :index, DataCycleCore::User
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

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Benutzer', locale: DataCycleCore.ui_language
      redirect_to users_path
    end

    def unlock
      @user.unlock_access!

      flash[:success] = I18n.t :unlocked, scope: [:controllers, :success], data: 'Benutzer', locale: DataCycleCore.ui_language
      redirect_to users_path
    end

    def search
      authorize! :show, DataCycleCore::User
      users = DataCycleCore::User.where('email ILIKE :q', q: "%#{params[:q]}%").limit(20)

      render json: users
    end

    private

    def permitted_params
      allowed_params = [:email, :family_name, :given_name, :name, :role_id, :notification_frequency, :type, :external, user_group_ids: []]
      allowed_params.push(:password, :password_confirmation, :current_password) unless params[controller_name.singularize.to_sym].blank? || params[controller_name.singularize.to_sym][:password].blank? || params[controller_name.singularize.to_sym][:password_confirmation].blank?
      params.require(controller_name.singularize.to_sym).permit(allowed_params)
    end

    def set_user
      @user = DataCycleCore::User.find(params[:id])
    end
  end
end
