# frozen_string_literal: true

module DataCycleCore
  class UsersController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource except: :search # from cancancan (authorize)
    before_action :set_user, only: [:edit, :update, :destroy, :unlock]

    BLOCKED_COLUMNS ||= ['encrypted_password', 'reset_password_token', 'current_sign_in_ip', 'last_sign_in_ip', 'provider', 'default_locale', 'type'].freeze

    def index
      @search_param = search_params[:q]
      @roles = DataCycleCore::Role.where(id: search_params[:roles]) if search_params[:roles].present?
      @user_groups = DataCycleCore::UserGroup.where(id: search_params[:user_groups]) if search_params[:user_groups].present?

      search_columns = DataCycleCore::User.columns
        .select { |c| (c.type == :string && BLOCKED_COLUMNS.exclude?(c.name)) || c.name == DataCycleCore::User.primary_key }
        .map { |c| "users.#{c.name}" }

      query = DataCycleCore::User.accessible_by(current_ability).except(:left_outer_joins).includes(:represented_by, :external_systems)

      query = query.where(locked_at: nil) unless current_user.has_rank?(10)

      if @search_param.present?
        search_term = @search_param.split(' ').map { |item| "concat_ws(' ', #{search_columns.join(', ')}) ILIKE '%#{item.strip}%'" }.join(' AND ')
        query = query.where(search_term)
      end

      query = query.joins(:role).where(role: @roles.ids) if @roles.present?
      query = query.joins(:user_groups).where(user_groups: { id: @user_groups.ids }) if @user_groups.present?

      @contents = query.preload(:role, :user_groups).order(:email).page(params[:page])

      if count_only_params[:count_only].present?
        @count_only = true
        @target = count_only_params[:target]
        @total_count = @contents.total_count
        @count_mode = count_only_params[:count_mode]
        @content_class = count_only_params[:content_class]
      end

      respond_to do |format|
        format.html
        format.js { render 'data_cycle_core/application/more_results' }
      end
    end

    def create_user
      @user = ('DataCycleCore::' + controller_name.singularize.classify).constantize.new(permitted_params.merge(creator: current_user))
      @user.raw_password = permitted_params[:password] if permitted_params[:password].present?

      if @user.save
        flash[:success] = I18n.t :created, scope: [:controllers, :success], data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale
      else
        flash[:error] = @user.try(:errors).try(:first).try(:[], 1)
      end
      redirect_back(fallback_location: root_path)
    end

    def edit
    end

    def update
      @permitted_params = permitted_params
      authorize! :set_role, @user if @permitted_params[:role_id].present?
      authorize! :generate_access_token, @user if params.dig(:user, :access_token).present?

      method = current_user == @user && @permitted_params[:password].present? ? 'update_with_password' : 'update'

      if params.dig(controller_name.singularize.to_sym, :access_token).present? && params.dig(controller_name.singularize.to_sym, :access_token) == '1' && @user.access_token.blank?
        @permitted_params[:access_token] = SecureRandom.hex
      elsif params.dig(controller_name.singularize.to_sym, :access_token).present? && params.dig(controller_name.singularize.to_sym, :access_token) == '0'
        @permitted_params[:access_token] = nil
      end

      if @user.send(method, @permitted_params)
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale

        bypass_sign_in(@user) if current_user == @user && !@permitted_params[:password].nil?

        if params[:user_settings]
          redirect_to(settings_path, notice: I18n.t(:updated_user_settings, scope: [:controllers, :success], locale: helpers.active_ui_locale))
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

      redirect_to users_path, notice: I18n.t(:locked, scope: [:controllers, :success], data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale)
    end

    def unlock
      @user.unlock_access!

      redirect_to users_path, notice: I18n.t(:unlocked, scope: [:controllers, :success], data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale)
    end

    def search
      authorize! :show, DataCycleCore::User
      users = DataCycleCore::User.where('email ILIKE :q', q: "%#{params[:q]}%").limit(20)

      render json: users
    end

    def become
      @user = User.find(params[:user_id])
      bypass_sign_in(@user)

      flash[:success] = I18n.t :become_user, scope: [:controllers, :success], data: @user.email, locale: helpers.active_ui_locale

      redirect_to authorized_root_path(@user)
    end

    private

    def search_params
      params.permit(:q, roles: [], user_groups: [])
    end

    def permitted_params
      allowed_params = [:email, :family_name, :given_name, :name, :role_id, :notification_frequency, :default_locale, :ui_locale, :type, :external, user_group_ids: []]
      allowed_params.push(:password, :password_confirmation, :current_password) if params.dig(controller_name.singularize.to_sym, :password).present? && params.dig(controller_name.singularize.to_sym, :password_confirmation).present?
      params.require(controller_name.singularize.to_sym).permit(allowed_params)
    end

    def set_user
      @user = DataCycleCore::User.find(params[:id])
    end

    def count_only_params
      params.permit(:target, :count_only, :count_mode, :content_class)
    end
  end
end
