# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module LifeCycle
        DataCycleCore::Engine.routes.append do
          unless has_named_route?(:update_life_cycle_stage)
            type_regexp = Regexp.new(*DataCycleCore.content_tables.map(&:to_sym).join('|'))
            patch '/:type/:id/update_life_cycle_stage', action: :update_life_cycle_stage, controller: :contents, constraints: { type: type_regexp }, as: 'update_life_cycle_stage'
          end
        end

        def update_life_cycle_stage
          @object = data_cycle_object(params[:type]).find_by(id: params[:id])
          authorize! :set_life_cycle, @object, life_cycle_params

          # Create idea_collection if it doesn't exist and active life_cycle_stage is correct
          if DataCycleCore::Feature::IdeaCollection.enabled? &&
             @object.content_type?('container') &&
             DataCycleCore::Feature::IdeaCollection.life_cycle_stage(@object) == life_cycle_params[:id] &&
             !@object.children.where(template_name: DataCycleCore::Feature::IdeaCollection.template).exists?
            idea_collection_params = ActionController::Parameters.new({ datahash: { headline: @object.headline } }).permit!
            idea_collection = DataCycleCore::DataHashService.create_internal_object(params[:type], DataCycleCore::Feature::IdeaCollection.template, idea_collection_params, current_user)
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
