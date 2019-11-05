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

          get_filtered_results
          @tree_page = @classification_trees.current_page
          @tree_total_pages = @classification_trees.total_pages
        end

        format.js do
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:ctl_id])

          if count_only_params[:count_only].present?
            @count_only = true
            @target = count_only_params[:target]
            @classification_tree = DataCycleCore::ClassificationTree.find(mode_params[:ct_id])
            @total_count = get_filtered_results

            if count_only_params[:container]
              @total_count = @total_count.part_of(mode_params[:con_id]) if count_only_params[:container]
            elsif count_only_params[:recursive]
              @total_count = @total_count.classification_alias_ids(@classification_tree.sub_classification_alias.id) if count_only_params[:recursive]
            else
              @total_count = @total_count.with_classification_alias_ids_without_recursion(@classification_tree.sub_classification_alias.id)
            end

            @total_count = @total_count.count_distinct

            render && return
          end

          if permitted_params[:con_id].present?
            @classification_parent_tree = DataCycleCore::ClassificationTree.find(permitted_params[:cpt_id])
            @container = DataCycleCore::Thing.find(permitted_params[:con_id])
            @order_string = 'things.boost DESC, things.template_name ASC, things.updated_at DESC'
            @contents = get_filtered_results
              .part_of(@container.id)
              .distinct_by_content_id(@order_string)
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

            @order_string = 'things.boost DESC, things.template_name ASC, things.updated_at DESC'
            @contents = get_filtered_results
              .with_classification_alias_ids_without_recursion(@classification_tree.sub_classification_alias.id)
              .distinct_by_content_id(@order_string)
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
            get_filtered_results # set default parameters for filters
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

    def count_only_params
      params.permit(:target, :count_only, :recursive, :container)
    end
  end
end
