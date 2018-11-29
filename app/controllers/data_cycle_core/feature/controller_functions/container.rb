# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module Container
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.append do
            unless has_named_route?(:set_parent_thing)
              post '/things/:id/set_parent', action: :set_parent, controller: 'things', as: 'set_parent_thing'
            end
          end
          Rails.application.reload_routes!
        end

        def set_parent
          @content = DataCycleCore::Thing.find(params[:id])
          authorize! :edit, @content

          redirect_back(fallback_location: root_path, alert: I18n.t(:invalid_parent, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if parent_params[:parent_id].blank?

          @parent = DataCycleCore::Thing.find(parent_params[:parent_id])

          I18n.with_locale(@content.first_available_locale) do
            @content.is_part_of = @parent.id
            if @content.save(touch: false)
              redirect_back(fallback_location: root_path, notice: I18n.t(:moved_to, scope: [:controllers, :success], locale: DataCycleCore.ui_language, data: @parent.title))
            else
              redirect_back(fallback_location: root_path, alert: @content.errors.full_messages)
            end
          end
        end

        private

        def parent_params
          params.permit(:parent_id)
        end
      end
    end
  end
end
