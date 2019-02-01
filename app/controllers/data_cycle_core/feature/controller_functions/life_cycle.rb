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
             !@object.children.where(template_name: DataCycleCore::Feature::IdeaCollection.template_name).exists?
            idea_collection_params = ActionController::Parameters.new({ datahash: { name: @object.name } }).permit!
            idea_collection = DataCycleCore::DataHashService.create_internal_object(DataCycleCore::Feature::IdeaCollection.template_name, idea_collection_params, current_user)
            idea_collection.is_part_of = @object.id unless @object.nil?
            idea_collection.save
          end

          valid = @object.set_life_cycle_classification(life_cycle_params[:id], current_user)

          redirect_back(fallback_location: root_path, alert: valid[:error]) && return if valid[:error].present?

          redirect_back(fallback_location: root_path, notice: (I18n.t :moved_to, scope: [:controllers, :success], data: life_cycle_params[:name], locale: DataCycleCore.ui_language))
        end
      end
    end
  end
end
