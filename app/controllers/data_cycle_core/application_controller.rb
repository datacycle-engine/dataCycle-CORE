# frozen_string_literal: true

module DataCycleCore
  class ApplicationController < ActionController::Base
    include ParamsResolver
    include DryParams
    include ErrorHandler
    include ActiveStorage::SetCurrent
    include RendererWithUser
    include UserRegistrationCheck if DataCycleCore::Feature::UserRegistration.enabled?

    protect_from_forgery with: :exception
    before_action :load_watch_list, if: -> { params[:watch_list_id].present? }
    before_action :clear_previous_page, if: -> { request.format.html? && !is_a?(DataCycleCore::ThingsController) && [consent_users_path, update_consent_users_path].exclude?(request.path) }
    before_action :better_errors_hack, if: -> { Rails.env.development? }
    before_action :flashes_from_params, if: -> { params[:flash].present? }

    def after_sign_in_path_for(resource)
      stored_location_for(resource).presence || authorized_root_path
    end

    def load_watch_list
      @watch_list = DataCycleCore::WatchList.find_by(id: params[:watch_list_id])
    end

    def current_ability
      return @current_ability if defined? @current_ability

      @current_ability = DataCycleCore::Ability.new(current_user, session)
    end

    def clear_all_caches
      authorize! :clear_all, :cache
      Rails.cache.clear

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: t('common.all_caches_cleared', locale: helpers.active_ui_locale)) }
        format.turbo_stream do
          flash.now[:success] = t('common.all_caches_cleared', locale: helpers.active_ui_locale)
          render turbo_stream: turbo_stream.append(:'flash-messages', partial: 'data_cycle_core/shared/flash')
        end
      end
    end

    def add_filter
      identifier = SecureRandom.hex(10)

      render json: { identifier:, html: render_to_string(formats: [:html], layout: false, locals: { filter_params: add_filter_params, identifier: }).strip }
    end

    def add_tag_group
      filter_params = tag_group_params

      render json: { identifier: filter_params['identifier'], html: render_to_string(formats: [:html], layout: false, locals: { filter_params: }).strip }
    end

    def remote_render
      @partial = remote_render_params[:partial]
      @render_function = remote_render_params[:render_function]
      @render_params = resolve_params(remote_render_params[:render_params])
      @options = resolve_params(remote_render_params[:options])
      @force_recursive_load = remote_render_params[:force_recursive_load]

      if @render_function.blank? && @partial.blank?
        respond_to do |format|
          format.json { render json: { error: I18n.t('controllers.error.missing_parameter', locale: helpers.active_ui_locale) }, status: :bad_request }
          format.html { render plain: I18n.t('controllers.error.missing_parameter', locale: helpers.active_ui_locale), status: :bad_request }
        end
      else
        respond_to do |format|
          format.json { render json: { html: render_to_string(formats: [:html], layout: false).strip } }
          format.html { render(formats: [:html], layout: false) }
        end
      end
    end

    def reload_required
      render(json: { error: I18n.t(:session_expired, scope: [:controllers, :error], locale: helpers.active_ui_locale), confirmation_text: I18n.t(:redirect_to_login, scope: [:actions], locale: helpers.active_ui_locale) }) && return unless user_signed_in?

      render(json: { error: I18n.t(:token_invalid, scope: [:controllers, :error], locale: helpers.active_ui_locale), confirmation_text: I18n.t(:reload, scope: [:actions], locale: helpers.active_ui_locale) }) && return unless any_authenticity_token_valid? || Rails.env.test?

      render(json: { error: I18n.t(:content_updated, scope: [:controllers, :info], locale: helpers.active_ui_locale), confirmation_text: I18n.t(:reload, scope: [:actions], locale: helpers.active_ui_locale) }) && return if "DataCycleCore::#{reload_params[:table]&.classify || 'Thing'}".safe_constantize&.find_by(id: reload_params[:id])&.updated_at&.>(reload_params[:datestring])

      head :no_content
    end

    def holidays
      head(:no_content) && return if DataCycleCore.holidays_country_code.blank? || holidays_params[:year].blank?

      render json: Holidays.between(Date.civil(holidays_params[:year].to_i, 1, 1), Date.civil(holidays_params[:year].to_i, 12, 31), Array.wrap(DataCycleCore.holidays_country_code)).to_json
    end

    def translate
      render(json: { error: 'error' }.to_json, status: :bad_request) && return if translate_params[:path].blank?
      render(json: { error: translate_params[:path] }.to_json, status: :not_found) && return unless I18n.exists?(translate_params[:path], locale: helpers.active_ui_locale)

      render json: { text: I18n.t(translate_params[:path], locale: helpers.active_ui_locale) }.to_json
    end

    private

    def better_errors_hack
      request.env['puma.config'].options.user_options.delete(:app) if request.env.key?('puma.config')
    end

    def translate_params
      params.permit(:path)
    end

    def remote_render_params
      params.slice(:partial, :render_function, :force_recursive_load, :render_params, :options).permit!
    end

    def reload_params
      params.permit(:id, :table, :datestring)
    end

    def authorized_root_path(user = nil, root_path_params = {})
      if (user || current_user)&.can?(:index, :backend)
        root_path(root_path_params)
      else
        unauthorized_exception_path
      end
    end

    def flash_params
      params.require(:flash).permit(:success, :notice, :alert, :error)
    end

    def flashes_from_params
      flash_params.each do |k, v|
        flash[k] = v # rubocop:disable Rails/ActionControllerFlashBeforeRender
      end

      redirect_to request.path, params: params.delete(:flash)
    end

    def tag_group_params
      options = {}
      key, filter = params.permit(:language_filter, :language, :roles, :user_groups, f: {}, language: [], roles: [], user_groups: []).to_h.first

      if key == 'f'
        identifier, value = filter&.first
        options = value || {}
        options[:identifier] = identifier
      else
        options[:n] = key
        options[:t] = key
        options[:c] = 'd'
        options[:v] = filter
        options[:identifier] = key
      end

      options.with_indifferent_access
    end

    def add_filter_params
      params.permit(:n, :m, :q, :t)
    end

    def holidays_params
      params.permit(:year)
    end

    def clear_previous_page
      session.delete(:return_to)
    end
  end
end
