# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module IdeaCollection
        extend ActiveSupport::Concern

        included do
          before_action :create_parent, only: :create, if: proc {
            params[:parent_id].blank? &&
              params[:template] == DataCycleCore::Feature::IdeaCollection.template_name
          }
        end

        private

        def create_parent
          object_params = content_params(params[:template])

          parent = DataCycleCore::DataHashService.create_internal_object(
            DataCycleCore::Feature::Container.available_containers&.first&.template_name,
            object_params,
            current_user
          )
          life_cycle_id = DataCycleCore::Feature::LifeCycle.ordered_classifications.dig(DataCycleCore::Feature::IdeaCollection.life_cycle_stage, :id)
          parent.set_data_hash(data_hash: { DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(parent).first => [life_cycle_id] }, current_user: current_user, partial_update: true)

          params[:parent_id] = parent&.id
        end
      end
    end
  end
end
