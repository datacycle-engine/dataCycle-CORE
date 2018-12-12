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
            update_hash = {
              current_user: current_user,
              save_time: Time.zone.now,
              partial_update: true,
              data_hash: {
                DataCycleCore::Feature::LifeCycle.attribute_keys(@content).first => [
                  @parent.try(:life_cycle_stage)&.id
                ]
              }
            }

            @content.is_part_of = @parent.id
            @content.save(touch: false)
            valid = @content.set_data_hash(update_hash)
            if valid[:error].present?
              redirect_back(fallback_location: root_path, alert: valid[:error])
            else
              redirect_back(fallback_location: root_path, notice: I18n.t(:moved_to, scope: [:controllers, :success], locale: DataCycleCore.ui_language, data: @parent.title))
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
