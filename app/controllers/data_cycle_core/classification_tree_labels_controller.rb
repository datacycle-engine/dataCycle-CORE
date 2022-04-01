# frozen_string_literal: true

module DataCycleCore
  class ClassificationTreeLabelsController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)

    def show
      respond_to do |format|
        format.html do
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:ctl_id])
          @classification_trees = @classification_tree_label.classification_trees.where(parent_classification_alias: nil)
          @classification_trees = @classification_trees.where.not(classification_aliases: { internal_name: DataCycleCore.excluded_filter_classifications }) if @classification_tree_label.name == 'Inhaltstypen'
          @classification_trees = @classification_trees
            .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
            .order('classification_aliases.internal_name')
            .page(params[:tree_page])

          get_filtered_results(user_filter: nil)
          @tree_page = @classification_trees.current_page
          @tree_total_pages = @classification_trees.total_pages
        end

        format.js do
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:ctl_id])

          return @total_count = total_count if count_only_params[:count_only].present?

          if permitted_params[:con_id].present?
            @classification_parent_tree = DataCycleCore::ClassificationTree.find(permitted_params[:cpt_id])
            @container = DataCycleCore::Thing.find(permitted_params[:con_id])
            # TODO: check if ordering is required
            # @order_string = 'things.boost DESC, things.template_name ASC, things.updated_at DESC'
            @contents = get_filtered_results(user_filter: nil)
              .part_of(@container.id)
              .content_includes
              .page(params[:page])

            @page = @contents.current_page
            @total_count = @contents.total_count
            @total_pages = @contents.total_pages
            render && return
          elsif permitted_params[:ct_id].present?
            @classification_tree = DataCycleCore::ClassificationTree.find(permitted_params[:ct_id])
            @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees
            @classification_trees = @classification_trees.where.not(classification_aliases: { internal_name: DataCycleCore.excluded_filter_classifications }) if @classification_tree_label.name == 'Inhaltstypen'
            @classification_trees = @classification_trees
              .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
              .order('classification_aliases.internal_name')
              .page(params[:tree_page])

            # TODO: check if ordering is required
            # @order_string = 'things.boost DESC, things.template_name ASC, things.updated_at DESC'
            @contents = get_filtered_results(user_filter: nil)
              .classification_alias_ids_without_subtree(@classification_tree.sub_classification_alias.id)
              .content_includes
              .page(params[:page])

            @page = @contents.current_page
            @total_count = @contents.total_count
            @total_pages = @contents.total_pages
          else
            @classification_trees = @classification_tree_label.classification_trees
              .where(parent_classification_alias: nil)
              .joins(:sub_classification_alias)
            @classification_trees = @classification_trees.where.not(classification_aliases: { internal_name: DataCycleCore.excluded_filter_classifications }) if @classification_tree_label.name == 'Inhaltstypen'
            @classification_trees = @classification_trees
              .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
              .order('classification_aliases.internal_name')
              .page(params[:tree_page])
            get_filtered_results(user_filter: nil) # set default parameters for filters
          end

          @tree_page = @classification_trees&.current_page
          @tree_total_pages = @classification_trees&.total_pages
        end
      end
    end

    private

    def permitted_params
      params.permit(:ct_id, :con_id, :ctl_id, :cpt_id)
    end
  end
end
