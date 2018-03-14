module DataCycleCore
  class ClassificationTreeLabelsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource # from cancancan (authorize)

    def show
      respond_to do |format|
        format.html do
          @classification_trees = @classification_tree_label.classification_trees.accessible_by(current_ability)
            .where(parent_classification_alias: nil)
            .order(:created_at).includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
        end
        format.js do
          if classification_tree_label_params[:classification_tree_id].present?
            @classification_tree = DataCycleCore::ClassificationTree.find(classification_tree_label_params[:classification_tree_id])
            @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees.accessible_by(current_ability).order(:created_at)

            query = DataCycleCore::Filter::Search.new(nil, DataCycleCore::Search)
            @contents = query.with_classification_alias_ids_without_recursion(@classification_tree.sub_classification_alias.id).includes(content_data: [:display_classification_aliases]).map(&:content_data)
          end
        end
      end

      # raise "test"
    end

    private

    def classification_tree_label_params
      params.permit(:classification_tree_id)
    end
  end
end
