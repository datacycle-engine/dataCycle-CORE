module DataCycleCore
  class ClassificationTreeLabelsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    def show
      respond_to do |format|
        format.html do
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:id])
          @classification_trees = @classification_tree_label.classification_trees
            .accessible_by(current_ability)
            .where(parent_classification_alias: nil)
            .where.not(classification_aliases: { name: DataCycleCore.excluded_filter_classifications })
            .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
            .order('classification_aliases.name')
            .page(params[:tree_page])

          @tree_page = @classification_trees.current_page
          @tree_total_pages = @classification_trees.total_pages

          @content_count = @classification_trees.map { |c|
            [
              c.id,
              DataCycleCore::Filter::Search.new(nil, DataCycleCore::Search.distinct)
                .with_classification_alias_ids_without_recursion(c.sub_classification_alias.id)
                .pluck(:content_data_id)
                .size
            ]
          }.to_h
        end

        format.js do
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:id])

          if permitted_params[:classification_tree_id].present?
            @classification_tree = DataCycleCore::ClassificationTree.find(permitted_params[:classification_tree_id])
            @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees
              .accessible_by(current_ability)
              .where.not(classification_aliases: { name: DataCycleCore.excluded_filter_classifications })
              .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
              .order('classification_aliases.name')
              .page(params[:tree_page])

            @contents = DataCycleCore::Filter::Search.new(nil, DataCycleCore::Search)
              .unique_by_column(:content_data_id)
              .with_classification_alias_ids_without_recursion(@classification_tree.sub_classification_alias.id)
              .includes(content_data: [:display_classification_aliases, :translations])
              .order(boost: :desc, data_type: :asc, headline: :asc)
              .page(params[:page])

            @page = @contents.current_page
            @total_count = @contents.total_count
            @total_pages = @contents.total_pages
            @contents = @contents.map(&:content_data)
          else
            @classification_trees = @classification_tree_label.classification_trees
              .accessible_by(current_ability)
              .where(parent_classification_alias: nil)
              .where.not(classification_aliases: { name: DataCycleCore.excluded_filter_classifications })
              .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
              .order('classification_aliases.name')
              .page(params[:tree_page])
          end

          @tree_page = @classification_trees.current_page
          @tree_total_pages = @classification_trees.total_pages

          @content_count = @classification_trees.map { |c|
            [
              c.id,
              DataCycleCore::Filter::Search.new(nil, DataCycleCore::Search.distinct)
                .with_classification_alias_ids_without_recursion(c.sub_classification_alias.id)
                .pluck(:content_data_id)
                .size
            ]
          }.to_h
        end
      end
    end

    private

    def permitted_params
      params.permit(:classification_tree_id, :id)
    end
  end
end
