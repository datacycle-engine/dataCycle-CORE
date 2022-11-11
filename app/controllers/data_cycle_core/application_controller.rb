# frozen_string_literal: true

module DataCycleCore
  class ApplicationController < ActionController::Base
    include DataCycleCore::ParamsResolver
    include DataCycleCore::ErrorHandler
    include ActiveStorage::SetCurrent

    protect_from_forgery with: :exception
    before_action :load_watch_lists, if: -> { params[:watch_list_id].present? }
    before_action :better_errors_hack, if: -> { Rails.env.development? }
    before_action :flashes_from_params, if: -> { params[:flash].present? }

    def after_sign_in_path_for(_resource)
      session['user_return_to'] || authorized_root_path
    end

    def load_watch_lists
      @watch_list = DataCycleCore::WatchList.find_by(id: params[:watch_list_id])
    end

    def current_ability
      return @current_ability if defined? @current_ability

      @current_ability = DataCycleCore::Ability.new(current_user, session)
      current_user&.instance_variable_set(:@ability, @current_ability)

      @current_ability
    end

    def clear_all_caches
      authorize! :clear_all, :cache
      Rails.cache.clear
      redirect_back(fallback_location: root_path)
    end

    def add_filter
      @identifier = SecureRandom.hex(10)
      @params = add_filter_params

      respond_to(:js)
    end

    def add_tag_group
      @params = tag_group_params

      respond_to(:js)
    end

    def remote_render
      @target = remote_render_params[:target]
      @partial = remote_render_params[:partial]
      @content_for = remote_render_params[:content_for]
      @render_function = remote_render_params[:render_function]
      @render_params = resolve_params(params[:render_params])
      @options = resolve_params(params[:options])
      @force_recursive_load = remote_render_params[:force_recursive_load]

      redirect_to(@render_params.merge(target: @target, partial: @partial)) && return if @render_params&.key?(:controller) && @render_params&.key?(:action)

      render(json: I18n.t(:missing_parameter, scope: [:controllers, :error], locale: helpers.active_ui_locale), status: :bad_request) && return unless (@target.present? && @render_function.present?) || @partial.present?

      respond_to(:js)
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
      params.permit(:target, :partial, :render_function, :force_recursive_load, content_for: [])
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
        flash[k] = v
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
  end
end
