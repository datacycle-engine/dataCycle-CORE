# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module DuplicateContent
        def create_duplication
          @object = DataCycleCore::Thing.find_by(id: params[:id])
          authorize! :create, @object
          new_content = DataCycleCore::DataHashService.create_duplicate(content: @object, current_user:)
          redirect_back(fallback_location: root_path, alert: I18n.t(:content_duplication_invalid, scope: [:controllers, :error], locale: helpers.active_ui_locale)) && return unless new_content
          redirect_to(thing_path(new_content, watch_list_params.merge(locale: I18n.locale)), notice: (I18n.t :created_duplication, scope: [:controllers, :info], data: new_content.title, locale: helpers.active_ui_locale))
        end
      end
    end
  end
end
