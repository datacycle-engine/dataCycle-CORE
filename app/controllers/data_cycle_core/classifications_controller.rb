module DataCycleCore
  class ClassificationsController < ApplicationController
    def index
      respond_to do |format|
        format.html do
          authorize! :read, DataCycleCore::ClassificationTreeLabel

          @classification_tree_labels = DataCycleCore::ClassificationTreeLabel.accessible_by(current_ability)
            .order(:created_at)
            .distinct
        end

        format.js do
          authorize! :read, DataCycleCore::ClassificationTree

          permitted_params = params.permit(:classification_tree_label_id, :classification_tree_id)

          if permitted_params.include?(:classification_tree_label_id)
            @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(params[:classification_tree_label_id])
            @classification_trees = @classification_tree_label.classification_trees.accessible_by(current_ability)
              .where(parent_classification_alias: nil)
              .order(:created_at)
          elsif permitted_params.include?(:classification_tree_id)
            @classification_tree = DataCycleCore::ClassificationTree.find(params[:classification_tree_id])
            @classification_tree_label = @classification_tree.classification_tree_label
            @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees.accessible_by(current_ability)
              .order(:created_at)
          else
            raise 'Missing parameter; either classification_tree_label_id or classification_tree_id must be provided'
          end
        end
      end
    end

    def search
      permitted_params = params.permit(:q, :max, :tree_label)

      render json: DataCycleCore::Classification
        .includes(:classification_groups, :classification_aliases)
        .joins(classification_aliases: [classification_tree: [:classification_tree_label]])
        .where('classification_tree_labels.name ILIKE ?', params[:tree_label].presence || '%')
        .where('classifications.name ILIKE ?', "%#{params[:q]}%")
        .limit(params[:max].try(:to_i) || 10).map(&:descendants).flatten.map { |c|
          {
            id: c.id,
            name: c.name,
            path: c.ancestors.reverse.map(&:name).join(' > '),
            disabled: !c.primary_classification_alias.try(:assignable)
          }
        }.uniq.first(params[:max].try(:to_i) || 10).sort_by { |c| c[:path] }
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
  end
end
