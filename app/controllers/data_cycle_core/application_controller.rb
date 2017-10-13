module DataCycleCore
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    before_action :load_watch_lists
    before_action :better_errors_hack, if: -> { Rails.env.development? }


    def load_watch_lists
      @accessible_watch_lists = DataCycleCore::WatchList.accessible_by(current_ability)
    end

    def current_ability
      @current_ability ||= ::Ability.new(current_user, session)
    end

    rescue_from CanCan::AccessDenied do |exception|
      respond_to do |format|
        format.json { head :forbidden, content_type: 'text/html' }
        format.html { redirect_back fallback_location: root_path, alert: exception.message }
        format.js   { head :forbidden, content_type: 'text/html' }
      end
    end

    private
      def better_errors_hack
        request.env['puma.config'].options.user_options.delete(:app) if request.env.has_key?('puma.config')
      end
  end
end
