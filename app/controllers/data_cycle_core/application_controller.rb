module DataCycleCore
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    
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
  end
end
