# frozen_string_literal: true

module DataCycleCore
  class ClassificationTreeLabelsController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)

    def show
      respond_to do |format|
        format.html do
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:id])
          @classification_trees = @classification_tree_label.classification_trees
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
              get_filtered_results
                .with_classification_alias_ids_without_recursion(c.sub_classification_alias.id)
                .count_distinct
            ]
          }.to_h
        end

        format.js do
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:id])

          if permitted_params[:classification_tree_id].present?
            @classification_tree = DataCycleCore::ClassificationTree.find(permitted_params[:classification_tree_id])
            @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees
              .where.not(classification_aliases: { name: DataCycleCore.excluded_filter_classifications })
              .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
              .order('classification_aliases.name')
              .page(params[:tree_page])

            @order_string = { boost: :desc, data_type: :asc, headline: :asc }
            @contents = get_filtered_results
              .with_classification_alias_ids_without_recursion(@classification_tree.sub_classification_alias.id)
              .distinct_by_content_id(@order_string)
              .content_includes
              .page(params[:page])

            @page = @contents.current_page
            @total_count = @contents.total_count
            @total_pages = @contents.total_pages
            @contents = @contents.map(&:content_data)
          else
            @classification_trees = @classification_tree_label.classification_trees
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
              get_filtered_results
                .with_classification_alias_ids_without_recursion(c.sub_classification_alias.id)
                .count_distinct
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
