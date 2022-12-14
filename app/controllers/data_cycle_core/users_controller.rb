# frozen_string_literal: true

module DataCycleCore
  class UsersController < ApplicationController
    load_and_authorize_resource except: [:search, :validate] # from cancancan (authorize)
    before_action :set_user, only: [:edit, :update, :destroy, :unlock]

    BLOCKED_COLUMNS ||= ['encrypted_password', 'reset_password_token', 'current_sign_in_ip', 'last_sign_in_ip', 'provider', 'default_locale', 'type'].freeze

    def index
      @search_param = search_params[:q]
      @roles = DataCycleCore::Role.where(id: search_params[:roles]) if search_params[:roles].present?
      @user_groups = DataCycleCore::UserGroup.where(id: search_params[:user_groups]) if search_params[:user_groups].present?

      query = DataCycleCore::User.accessible_by(current_ability).except(:left_outer_joins).includes(:represented_by, :external_systems)

      query = query.where(locked_at: nil) unless current_user.has_rank?(10)

      query = query.where(sql_for_fulltext_search(@search_param)) if @search_param.present?

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
        format.json { render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/application/count_or_more_results').squish } }
      end
    end

    def create_user
      @user = ('DataCycleCore::' + controller_name.singularize.classify).constantize.new(permitted_params.merge(creator: current_user))
      @user.raw_password = permitted_params[:password] if permitted_params[:password].present?

      if @user.save
        flash[:success] = I18n.t :created, scope: [:controllers, :success], data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale
      else
        flash[:error] = I18n.with_locale(helpers.active_ui_locale) { @user.errors.messages.transform_keys { |k| @user.class.human_attribute_name(k, locale: helpers.active_ui_locale) } }
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
          flash.clear[:success] = I18n.t(:updated_user_settings, scope: [:controllers, :success], locale: helpers.active_ui_locale)
          redirect_to(settings_path)
        elsif Rails.env.development?
          redirect_to edit_user_path(@user)
        elsif can? :index, DataCycleCore::User
          redirect_to users_path
        else
          redirect_to root_path
        end
      else
        flash.now[:error] = I18n.with_locale(helpers.active_ui_locale) { @user.errors.messages.transform_keys { |k| @user.class.human_attribute_name(k, locale: helpers.active_ui_locale) } }

        render :edit
      end
    end

    def destroy
      @user.lock_access!

      redirect_back(fallback_location: root_path, notice: I18n.t(:locked, scope: [:controllers, :success], data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def unlock
      @user.unlock_access!

      redirect_back(fallback_location: root_path, notice: I18n.t(:unlocked, scope: [:controllers, :success], data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def confirm
      @user.confirm

      redirect_back(fallback_location: root_path, notice: I18n.t('controllers.success.confirmed', data: @user.email, locale: helpers.active_ui_locale))
    end

    def search
      authorize! :show, DataCycleCore::User

      users = DataCycleCore::User.all.limit(20)
      users = users.where(sql_for_fulltext_search(search_params[:q])) if search_params[:q].present?

      render plain: users.map { |u| u.to_select_option(helpers.active_ui_locale) }.to_json, content_type: 'application/json'
    end

    def become
      @user = User.find(params[:user_id])
      bypass_sign_in(@user)

      flash[:success] = I18n.t :become_user, scope: [:controllers, :success], data: @user.email, locale: helpers.active_ui_locale

      redirect_to authorized_root_path(@user)
    end

    def validate
      user_type = "DataCycleCore::#{controller_name.classify}".safe_constantize
      @user = user_type.find_by(id: params[:id]) || user_type.new

      authorize! :show, @user

      @user.attributes = permitted_params
      @user.valid?
      @messages = @user.errors.messages.slice(*permitted_params.keys.map(&:to_sym))

      render json: {
        valid: @messages.blank?,
        errors: @messages,
        warnings: {}
      }.to_json
    end

    private

    def sql_for_fulltext_search(search_term)
      search_columns = DataCycleCore::User.columns
        .select { |c| (c.type == :string && BLOCKED_COLUMNS.exclude?(c.name)) || c.name == DataCycleCore::User.primary_key }
        .map { |c| "users.#{c.name}" }

      search_term.to_s.split(' ').map { |term| "concat_ws(' ', #{search_columns.join(', ')}) ILIKE '%#{term.strip}%'" }.join(' AND ')
    end

    def search_params
      params
        .permit(:q, roles: [], user_groups: [])
        .tap { |p| p[:q]&.strip! }
    end

    def permitted_params
      allowed_params = [:email, :family_name, :given_name, :name, :role_id, :notification_frequency, :default_locale, :ui_locale, :type, :external, user_group_ids: []]
      allowed_params.push(:password, :current_password) if params.dig(controller_name.singularize.to_sym, :password).present?
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
