# frozen_string_literal: true

module DataCycleCore
  class ApplicationController < ActionController::Base
    include DataCycleCore::ParamsResolver
    include DataCycleCore::ErrorHandler
    protect_from_forgery with: :exception
    before_action :load_watch_lists
    before_action :load_stored_filters
    before_action :better_errors_hack, if: -> { Rails.env.development? }
    before_action :flashes_from_params, if: -> { params[:flash].present? }

    def after_sign_in_path_for(_resource)
      session['user_return_to'] || authorized_root_path
    end

    def load_watch_lists
      @watch_list = DataCycleCore::WatchList.find_by(id: params[:watch_list_id]) if params[:watch_list_id]
    end

    def load_stored_filters
      @accessible_stored_filters = DataCycleCore::StoredFilter.accessible_by(current_ability)
    end

    def current_ability
      @current_ability ||= DataCycleCore::Ability.new(current_user, session)
    end

    def clear_all_caches
      authorize! :clear_all, :cache
      Rails.cache.clear
      redirect_back(fallback_location: root_path)
    end

    def add_filter
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

      redirect_to(@render_params.merge(target: @target, partial: @partial)) && return if @render_params&.key?(:controller) && @render_params&.key?(:action)

      render(json: I18n.t(:missing_parameter, scope: [:controllers, :error], locale: DataCycleCore.ui_language), status: :bad_request) && return unless (@target.present? && @render_function.present?) || @partial.present?

      respond_to(:js)
    end

    def reload_required
      render(json: { error: I18n.t(:session_expired, scope: [:controllers, :error], locale: DataCycleCore.ui_language), confirmation_text: I18n.t(:redirect_to_login, scope: [:actions], locale: DataCycleCore.ui_language) }) && return unless user_signed_in?

      render(json: { error: I18n.t(:token_invalid, scope: [:controllers, :error], locale: DataCycleCore.ui_language), confirmation_text: I18n.t(:reload, scope: [:actions], locale: DataCycleCore.ui_language) }) && return unless any_authenticity_token_valid? || Rails.env.test?

      render(json: { error: I18n.t(:content_updated, scope: [:controllers, :info], locale: DataCycleCore.ui_language), confirmation_text: I18n.t(:reload, scope: [:actions], locale: DataCycleCore.ui_language) }) && return if "DataCycleCore::#{reload_params[:table]&.classify || 'Thing'}".safe_constantize&.find_by(id: reload_params[:id])&.updated_at&.>(reload_params[:datestring])

      head :no_content
    end

    private

    def better_errors_hack
      request.env['puma.config'].options.user_options.delete(:app) if request.env.key?('puma.config')
    end

    def remote_render_params
      params.permit(:target, :partial, :render_function, content_for: [])
    end

    def reload_params
      params.permit(:id, :table, :datestring)
    end

    def authorized_root_path(user = nil)
      if (user || current_user)&.can?(:index, :backend)
        root_path
      else
        info_path
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
        index, value = filter&.first
        options = value || {}
        options[:index] = index
      else
        options[:n] = key
        options[:t] = key
        options[:c] = 'd'
        options[:v] = filter
      end

      options.with_indifferent_access
    end

    def add_filter_params
      params.permit(:n, :m, :q, :t, :index)
    end
  end
end
