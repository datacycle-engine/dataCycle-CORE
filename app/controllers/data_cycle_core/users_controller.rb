# frozen_string_literal: true

module DataCycleCore
  class UsersController < ApplicationController
    load_and_authorize_resource except: [:search, :validate, :consent, :update_consent] # from cancancan (authorize)
    before_action :set_user, only: [:edit, :update, :destroy, :unlock, :update_consent]

    def index
      query = filterd_users

      @mode = mode_params[:mode].in?(['list', 'tree', 'map']) ? mode_params[:mode].to_s : 'grid'

      @contents = query.preload(:role, :user_groups).page(params[:page])

      if count_only_params[:count_only].present?
        @count_only = true
        @target = count_only_params[:target]
        @total_count = @contents.total_count
        @count_mode = count_only_params[:count_mode]
        @content_class = count_only_params[:content_class]
      end

      respond_to do |format|
        format.html
        format.json { render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/application/count_or_more_results').strip } }
      end
    end

    def create_user
      @user = DataCycleCore::User.new(permitted_params.merge(creator: current_user))
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

      (@user.additional_attributes ||= {}).merge!(permitted_params[:additional_attributes]) if @permitted_params[:additional_attributes].present?

      if @user.send(method, @permitted_params.except(:additional_attributes))
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
      @user.destroy!
      sign_out(@user) if current_user == @user

      redirect_back(fallback_location: root_path, notice: I18n.t('controllers.success.destroyed', data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def lock
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

      users = DataCycleCore::User.limit(20)
      users = users.fulltext_search(search_params[:q]) if search_params[:q].present?

      render plain: users.map { |u| u.to_select_option(helpers.active_ui_locale, search_params[:disable_locked].to_s != 'false') }.to_json, content_type: 'application/json'
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

      if @user.new_record?
        authorize! :edit, DataCycleCore::User
      else
        authorize! :edit, @user
      end

      @user.attributes = permitted_params
      @user.valid?
      @messages = @user.errors.messages.slice(*permitted_params.keys.map(&:to_sym))

      render json: {
        valid: @messages.blank?,
        errors: @messages,
        warnings: {}
      }.to_json
    end

    def consent
      authorize! :edit, current_user

      @type = consent_params[:type]

      render 'consent', layout: 'layouts/data_cycle_core/devise'
    end

    def update_consent
      authorize! :update, @user

      (@user.additional_attributes ||= {}).merge!(permitted_params[:additional_attributes]) if permitted_params[:additional_attributes].present?

      flash[:error] = @user.errors.full_messages unless @user.save

      redirect_to(session.delete(:return_to) || root_path)
    end

    def download_user_info_activity
      users = filterd_users
      user_ids = users.pluck(:id)
      activity = DataCycleCore::Report::Downloads::UserInfoActivity.new(params: { key: 'user_info_activity', user_ids: })
      data, options = activity.to_csv
      send_data data, options
    end

    private

    def consent_params
      params.permit(:type)
    end

    def search_params
      params
        .permit(:q, :disable_locked, roles: [], user_groups: [])
        .tap { |p| p[:q]&.strip! }
    end

    def permitted_params
      allowed_params = [:email, :family_name, :given_name, :name, :role_id, :notification_frequency, :default_locale, :ui_locale, :type, :external, user_group_ids: [], additional_attributes: {}]
      allowed_params.push(:password, :current_password) if params.dig(controller_name.singularize.to_sym, :password).present?
      params.require(controller_name.singularize.to_sym).permit(allowed_params)
    end

    def set_user
      @user = DataCycleCore::User.find(params[:id])
    end

    def count_only_params
      params.permit(:target, :count_only, :count_mode, :content_class)
    end

    def sort_params
      params.permit(s: {}).to_h[:s].presence&.values&.reject { |s| DataCycleCore::DataHashService.blank?(s) }
    end

    def mode_params
      params.permit(:mode)
    end

    def filter_params
      params.permit(f: {}).to_h[:f].presence&.values&.reject { |f| DataCycleCore::DataHashService.blank?(f) || DataCycleCore::DataHashService.blank?(f['v']) }
    end

    def filterd_users
      query = DataCycleCore::User.accessible_by(current_ability).except(:left_outer_joins).includes(:represented_by, :external_systems)

      query = query.where(locked_at: nil) unless current_user.has_rank?(10)

      @filters = filter_params
      @filters&.select { |f| f.key?('c') }&.each { |f| f['identifier'] = SecureRandom.hex(10) }

      @filters&.each do |filter|
        filter_method = (filter['c'] == 'd' ? filter['n'] : filter['t']).dup
        filter_method = +"#{filter['t']}_#{filter['n']}" if filter['c'] == 'a' && query.respond_to?("#{filter['t']}_#{filter['n']}")
        filter_method.prepend(DataCycleCore::StoredFilterExtensions::FilterParamsHashParser::FILTER_PREFIX[filter['m']].to_s)

        next unless query.respond_to?(filter_method)

        query = query.send(filter_method, filter['v'])
      end

      @sort_params = sort_params
      if @sort_params.present?
        query = query.order(*@sort_params.map { |s| { s[:m].to_sym => s[:o].to_sym } })
      else
        query = query.order(:email)
      end
    end
  end
end
