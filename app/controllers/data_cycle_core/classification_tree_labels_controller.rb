module DataCycleCore
  class ClassificationTreeLabelsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource # from cancancan (authorize)

    def show
      respond_to do |format|
        format.html do
          @classification_trees = @classification_tree_label.classification_trees.accessible_by(current_ability)
            .where(parent_classification_alias: nil)
            .where.not(classification_aliases: { name: DataCycleCore.excluded_filter_classifications })
            .order('classification_aliases.name').includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])

          @content_count = @classification_trees.map { |c| [c.id, DataCycleCore::Filter::Search.new(nil, DataCycleCore::Search.distinct).with_classification_alias_ids_without_recursion(c.sub_classification_alias.id).pluck(:content_data_id).count] }.to_h
        end
        format.js do
          if classification_tree_label_params[:classification_tree_id].present?
            @classification_tree = DataCycleCore::ClassificationTree.find(classification_tree_label_params[:classification_tree_id])
            @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees
              .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source]).accessible_by(current_ability)
              .where.not(classification_aliases: { name: DataCycleCore.excluded_filter_classifications })
              .order('classification_aliases.name')

            @content_count = @classification_trees.map { |c| [c.id, DataCycleCore::Filter::Search.new(nil, DataCycleCore::Search.distinct).with_classification_alias_ids_without_recursion(c.sub_classification_alias.id).pluck(:content_data_id).count] }.to_h

            query = DataCycleCore::Filter::Search.new(nil, DataCycleCore::Search)

            @contents = query
              .with_classification_alias_ids_without_recursion(@classification_tree.sub_classification_alias.id)
              .includes(content_data: [:display_classification_aliases])
              .order(boost: :desc, data_type: :asc, headline: :asc)

            @contents = @contents.page(params[:page])

            @page = @contents.current_page
            @total_count = @contents.total_count
            @total_pages = @contents.total_pages
            @contents = @contents.map(&:content_data)
          end
        end
      end
    end

    private

    def classification_tree_label_params
      params.permit(:classification_tree_id)
    end
  end
end
