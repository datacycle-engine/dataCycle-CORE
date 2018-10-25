# frozen_string_literal: true

module DataCycleCore
  class ApplicationController < ActionController::Base
    include DataCycleCore::Common
    include DataCycleCore::ParamsResolver
    protect_from_forgery with: :exception
    before_action :load_watch_lists
    before_action :load_stored_filters
    before_action :better_errors_hack, if: -> { Rails.env.development? }

    def after_sign_in_path_for(_resource)
      if can?(:index, :backend)
        session['user_return_to'] || root_path
      else
        session['user_return_to'] || info_path
      end
    end

    def load_watch_lists
      @watch_list = DataCycleCore::WatchList.find_by(id: params[:watch_list_id]) if params[:watch_list_id]
      @accessible_watch_lists = DataCycleCore::WatchList.accessible_by(current_ability).includes(:valid_write_links)
    end

    def load_stored_filters
      @accessible_stored_filters = DataCycleCore::StoredFilter.accessible_by(current_ability)
    end

    def current_ability
      @current_ability ||= DataCycleCore::Ability.new(current_user, session)
    end

    def add_filter
      respond_to(:js)
    end

    def add_tag_group
      respond_to(:js)
    end

    def remote_render
      @target = remote_render_params[:target]
      @partial = remote_render_params[:partial]
      @content_for = remote_render_params[:content_for]
      @render_function = remote_render_params[:render_function]

      @render_params = resolve_params(params[:render_params])
      @options = resolve_params(params[:options])

      render(json: I18n.t(:missing_parameter, scope: [:controllers, :error], locale: DataCycleCore.ui_language), status: :bad_request) && return if (@target.blank? && @render_function.blank?) || @partial.blank?

      respond_to(:js)
    end

    rescue_from CanCan::AccessDenied do |exception|
      respond_to do |format|
        format.json { head :forbidden, content_type: 'text/html' }
        format.js   { head :forbidden, content_type: 'text/html' }
        if current_user&.is_rank?(0)
          format.html { redirect_back fallback_location: info_path, alert: exception.message }
        else
          format.html { redirect_back fallback_location: root_path, alert: exception.message }
        end
      end
    end

    private

    def better_errors_hack
      request.env['puma.config'].options.user_options.delete(:app) if request.env.key?('puma.config')
    end

    def remote_render_params
      params.permit(:target, :partial, :render_function, content_for: [])
    end
  end
end
