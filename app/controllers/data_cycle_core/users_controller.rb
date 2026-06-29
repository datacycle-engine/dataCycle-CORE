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

      authorize_role_assignment!(permitted_params[:role_id]) if permitted_params[:role_id].present?
      authorize! :generate_access_token, @user if permitted_params[:access_token].present?

      if @user.save
        flash[:success] = I18n.t 'controllers.success.created', data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale
      else
        flash[:error] = I18n.with_locale(helpers.active_ui_locale) { @user.errors.messages.transform_keys { |k| @user.class.human_attribute_name(k, locale: helpers.active_ui_locale) } }
      end

      redirect_to(user_path(@user))
    end

    def edit
    end

    def update
      @permitted_params = permitted_params

      if @permitted_params[:role_id].present?
        authorize! :set_role, @user
        authorize_role_assignment!(@permitted_params[:role_id])
      end

      authorize! :generate_access_token, @user if params.dig(:user, :access_token).present?

      method = current_user == @user && @permitted_params[:password].present? ? 'update_with_password' : 'update'

      @permitted_params[:access_token] = @user.access_token if @permitted_params[:access_token].present? && @user.access_token.present?

      (@user.additional_attributes ||= {}).merge!(permitted_params[:additional_attributes]) if @permitted_params[:additional_attributes].present?

      if @user.send(method, @permitted_params.except(:additional_attributes))
        flash[:success] = I18n.t 'controllers.success.updated', data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale

        bypass_sign_in(@user) if current_user == @user && !@permitted_params[:password].nil?

        if params[:user_settings]
          flash.clear[:success] = I18n.t('controllers.success.updated_user_settings', locale: helpers.active_ui_locale)
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

      redirect_back_or_to(root_path, notice: I18n.t('controllers.success.destroyed', data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def lock
      @user.lock_access!

      redirect_back_or_to(root_path, notice: I18n.t('controllers.success.locked', data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def unlock
      @user.unlock_access!

      redirect_back_or_to(root_path, notice: I18n.t('controllers.success.unlocked', data: DataCycleCore::User.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def confirm
      @user.confirm

      redirect_back_or_to(root_path, notice: I18n.t('controllers.success.confirmed', data: @user.email, locale: helpers.active_ui_locale))
    end

    def search
      authorize! :search, :users

      users = DataCycleCore::User.limit(20)
      users = users.fulltext_search(search_params[:q]) if search_params[:q].present?
      users = users.to_a

      visible_ids = DataCycleCore::User.where(id: users.map(&:id)).accessible_by(current_ability, :show).pluck(:id).to_set

      render plain: users.map { |u| u.to_select_option(helpers.active_ui_locale, search_params[:disable_locked].to_s != 'false', mask_email: visible_ids.exclude?(u.id)) }.to_json, content_type: 'application/json'
    end

    def become
      @user = User.find(params[:user_id])
      bypass_sign_in(@user)

      flash[:success] = I18n.t 'controllers.success.become_user', data: @user.email, locale: helpers.active_ui_locale

      redirect_to authorized_root_path(@user)
    end

    def validate
      @user = DataCycleCore::User.find_by(id: params[:id]) ||
              DataCycleCore::User.new

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

    # DC-20: role_id is mass-assignable and the :set_role ability only checks the *target's current*
    # role, never the role being granted — so an admin could assign super_admin (or, for an oauth user,
    # system_admin) and escalate above their own tier. Restrict assignable roles to the actor's own rank
    # or below. This matches the intent of the UsersExceptRoles ability config (admin excludes
    # super_admin/system_admin, super_admin excludes system_admin); the difference is the gate is now
    # applied to the role being *assigned* rather than the target's existing role.
    def authorize_role_assignment!(role_id)
      assigned_role = DataCycleCore::Role.find_by(id: role_id)

      return if assigned_role.present? && current_user.role.present? && assigned_role.rank.to_i <= current_user.role.rank.to_i

      raise CanCan::AccessDenied.new(nil, :set_role, DataCycleCore::User)
    end

    def consent_params
      params.permit(:type)
    end

    def search_params
      params
        .permit(:q, :disable_locked, roles: [], user_groups: [])
        .tap { |p| p[:q]&.strip! }
    end

    def permitted_params
      allowed_params = [:email, :family_name, :given_name, :name, :role_id, :notification_frequency, :default_locale, :ui_locale, :type, :external, :access_token, :password, :current_password, { user_group_ids: [], additional_attributes: {} }]
      permitted = params.expect(user: allowed_params)
      permitted = permitted.except(:password, :current_password) if permitted[:password].blank?

      if permitted[:access_token] == '1'
        permitted[:access_token] = SecureRandom.hex
      elsif permitted[:access_token] == '0'
        permitted[:access_token] = nil
      end

      permitted
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
        filter_method = "#{filter['t']}_#{filter['n']}" if filter['c'] == 'a' && query.respond_to?(:"#{filter['t']}_#{filter['n']}")
        filter_method.prepend(DataCycleCore::Type::StoredFilter::Parameters::FILTER_PREFIX[filter['m']].to_s)

        next unless query.respond_to?(filter_method)

        query = query.send(filter_method, filter['v'])
      end

      @sort_params = sort_params
      query = if @sort_params.present?
                query.order(*@sort_params.map { |s| { s[:m].to_sym => s[:o].to_sym } })
              else
                query.order(:email)
              end
    end
  end
end
