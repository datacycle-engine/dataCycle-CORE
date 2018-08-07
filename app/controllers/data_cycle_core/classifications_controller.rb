# frozen_string_literal: true

module DataCycleCore
  class ClassificationsController < ApplicationController
    FIXNUM_MAX = (2**(0.size * 8 - 2) - 1)

    DEFAULT_CLASSIFICATION_SEARCH_LIMIT = 128

    def index
      respond_to do |format|
        format.html do
          authorize! :index, DataCycleCore::ClassificationTreeLabel

          @classification_tree_labels = DataCycleCore::ClassificationTreeLabel.accessible_by(current_ability)
            .order(:created_at)
            .distinct
        end

        format.js do
          authorize! :index, DataCycleCore::ClassificationTree

          permitted_params = params.permit(:classification_tree_label_id, :classification_tree_id)

          if permitted_params.include?(:classification_tree_label_id)
            @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(params[:classification_tree_label_id])
            @classification_trees = @classification_tree_label.classification_trees.accessible_by(current_ability)
              .where(parent_classification_alias: nil)
              .order(:created_at).page(params[:page])
            @page = @classification_trees.current_page
            @total_pages = @classification_trees.total_pages
          elsif permitted_params.include?(:classification_tree_id)
            @classification_tree = DataCycleCore::ClassificationTree.find(params[:classification_tree_id])
            @classification_tree_label = @classification_tree.classification_tree_label
            @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees.accessible_by(current_ability)
              .order(:created_at).page(params[:page])
            @page = @classification_trees.current_page
            @total_pages = @classification_trees.total_pages
          else
            raise 'Missing parameter; either classification_tree_label_id or classification_tree_id must be provided'
          end
        end
      end
    end

    def search
      params.permit(:q, :max, :tree_label)

      query = if params[:tree_label].present?
                DataCycleCore::ClassificationAlias.for_tree(params[:tree_label]).where.not(name: DataCycleCore.excluded_filter_classifications)
              else
                DataCycleCore::ClassificationAlias.all
              end
      query = query.search(params[:q])
      query = query.order_by_similarity(params[:q])
      query = query.limit(params[:max].try(:to_i) || DEFAULT_CLASSIFICATION_SEARCH_LIMIT)
      query = query.preload(:classifications, :classification_alias_path)

      # FIXME: Jbuilder Bug: tries to render jbuilder partial
      render plain: query.map { |a|
        {
          classification_id: a.primary_classification.id,
          classification_alias_id: a.id,
          name: a.name,
          title: a.full_path,
          disabled: !a.assignable
        }
      }.to_json, content_type: 'application/json'
    end

    def create
      permitted_params = params.permit(
        :classification_tree_label_id,
        :classification_tree_id,
        { classification_tree_label: [:name, :internal] },
        { classification_alias: [:name, :internal, :assignable] }
      )

      respond_to do |format|
        format.html do
          raise NotImplemented
        end

        format.js do
          if permitted_params[:classification_tree_label]
            @object = DataCycleCore::ClassificationTreeLabel.create!(permitted_params[:classification_tree_label])
          else
            @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:classification_tree_label_id])

            if permitted_params['classification_tree_id']
              @parent_classification_tree = DataCycleCore::ClassificationTree.find(permitted_params['classification_tree_id'])
            else
              @parent_classification_tree = nil
            end

            ActiveRecord::Base.transaction do
              @classification = DataCycleCore::Classification.create!(name: permitted_params[:classification_alias][:name])
              @classification_alias = DataCycleCore::ClassificationAlias.create!(permitted_params[:classification_alias])
              @classification_group = DataCycleCore::ClassificationGroup.create!(
                classification: @classification,
                classification_alias: @classification_alias
              )
              @object = DataCycleCore::ClassificationTree.create!({
                                                                    classification_tree_label: @classification_tree_label,
                                                                    parent_classification_alias: @parent_classification_tree.try(:sub_classification_alias),
                                                                    sub_classification_alias: @classification_alias
                                                                  })
            end
          end
        end
      end
    end

    def update
      permitted_params = params.permit(
        classification_tree_label: [:id, :name, :internal],
        classification_alias: [:id, :name, :internal, :assignable, classification_ids: []]
      )

      respond_to do |format|
        format.html do
          raise NotImplemented
        end

        format.js do
          if permitted_params[:classification_tree_label]
            @object = DataCycleCore::ClassificationTreeLabel.find(permitted_params[:classification_tree_label][:id])
            @object.update_attributes!(permitted_params[:classification_tree_label])
          else
            @object = DataCycleCore::ClassificationAlias.find(permitted_params[:classification_alias][:id])
            @object.update_attributes!(permitted_params[:classification_alias])
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
          elsif permitted_params.include?(:classification_tree_id)
            @object = DataCycleCore::ClassificationTree.find(params[:classification_tree_id])
          else
            raise 'Missing parameter; either classification_tree_label_id or classification_tree_id must be provided'
          end

          authorize! :destroy, @object

          @object.destroy
        end
      end
    end

    def download
      object = DataCycleCore::ClassificationTreeLabel.find(params[:classification_tree_label_id])

      respond_to do |format|
        format.csv do
          send_data "sep=,\n" + object.to_csv.encode('ISO-8859-1', invalid: :replace, undef: :replace),
                    type: 'text/csv; charset=iso-8859-1;',
                    filename: "#{object.name}.csv"
        end
      end
    end
  end
end
