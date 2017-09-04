module DataCycleCore
  class ClassificationsController < ApplicationController
    layout 'data_cycle_core/admin'

    def index
      authorize! :manage, DataCycleCore::Classification

      respond_to do |format|
        format.html do
          @classification_tree_labels = DataCycleCore::ClassificationTreeLabel.accessible_by(current_ability).uniq
        end

        format.js do
          permitted_params = params.permit(:classification_tree_label_id, :classification_tree_id)

          if permitted_params.include?(:classification_tree_label_id)
            @classification_tree = DataCycleCore::ClassificationTreeLabel.find(params[:classification_tree_label_id])
            @classification_trees = @classification_tree.classification_trees.accessible_by(current_ability).where(parent_classification_alias: nil)
          elsif permitted_params.include?(:classification_tree_id)
            @classification_tree = DataCycleCore::ClassificationTree.find(params[:classification_tree_id])
            @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees.accessible_by(current_ability)
          else
            raise 'Missing parameter; either classification_tree_label_id or classification_tree_id must be provided'
          end
        end
      end
    end

    def destroy
      permitted_params = params.permit(:classification_tree_label_id, :classification_tree_id)

      respond_to do |format|
        format.html do
          raise NotImplemented
        end

        format.js do
          if permitted_params.include?(:classification_tree_label_id)
            @object = DataCycleCore::ClassificationTreeLabel.find(params[:classification_tree_label_id])
            # @object.destroy
          elsif permitted_params.include?(:classification_tree_id)
            @object = DataCycleCore::ClassificationTree.find(params[:classification_tree_id])
            # @object.sub_classification_alias.destroy
          else
            raise 'Missing parameter; either classification_tree_label_id or classification_tree_id must be provided'
          end
        end
      end
    end
  end
end
