# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module LifeCycle
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.append do
            patch '/things/:id/update_life_cycle', action: :update_life_cycle, controller: 'things', as: 'update_life_cycle_thing' unless has_named_route?(:update_life_cycle_thing)
          end
          Rails.application.reload_routes!
        end

        def update_life_cycle
          @object = DataCycleCore::Thing.find_by(id: params[:id])
          authorize! :set_life_cycle, @object, life_cycle_params

          # Create idea_collection if it doesn't exist and active life_cycle_stage is correct
          if DataCycleCore::Feature::IdeaCollection.enabled? &&
             @object.content_type?('container') &&
             DataCycleCore::Feature::IdeaCollection.life_cycle_stage(@object) == life_cycle_params[:id] &&
             !@object.children.exists?(template_name: DataCycleCore::Feature::IdeaCollection.template_name)
            idea_collection_params = ActionController::Parameters.new({ datahash: { name: @object.name } }).permit!
            DataCycleCore::DataHashService.create_internal_object(DataCycleCore::Feature::IdeaCollection.template_name, idea_collection_params, current_user, @object&.id)
          end

          if @object.set_life_cycle_classification(life_cycle_params[:id], current_user)
            flash[:success] = I18n.t('controllers.success.moved_to', data: life_cycle_params[:name], locale: helpers.active_ui_locale)
          else
            flash[:error] = I18n.with_locale(active_ui_locale) { @object.errors.full_messages }
          end

          respond_to do |format|
            format.html { redirect_back(fallback_location: root_path) }
            format.json do
              render json: {
                life_cycle_html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/contents/viewers/life_cycle', locals: { content: @object }).squish,
                classifications_html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/contents/detail/content_header_classifications', locals: { content: @object }).squish,
                **flash.discard.to_h
              }
            end
          end
        end
      end
    end
  end
end
