module DataCycleCore
  class Api::V1::ClassificationTreesController < Api::V1::ApiBaseController
    def index
      @classification_tree_labels = ClassificationTreeLabel.where(internal: false)

      if params[:modified_since]
        @classification_tree_labels = @classification_tree_labels.where(
          ClassificationTreeLabel.arel_attribute(:updated_at).gteq(DateTime.parse(params[:modified_since]))
        ).order(:updated_at)
      end

      if params[:created_since]
        @classification_tree_labels = @classification_tree_labels.where(
          ClassificationTreeLabel.arel_attribute(:created_at).gteq(DateTime.parse(params[:created_since]))
        ).order(:created_at)
      end

      if params[:deleted_since]
        @classification_tree_labels = @classification_tree_labels.with_deleted.where(
          ClassificationTreeLabel.arel_attribute(:deleted_at).gteq(DateTime.parse(params[:deleted_since]))
        ).order(:deleted_at)
      end

      @classification_tree_labels = @classification_tree_labels.page(params[:page])
    end

    def show
      @classification_tree_label = ClassificationTreeLabel.find(params[:id])
      @classification_aliases = @classification_tree_label.classification_aliases.where(internal: false).page(params[:page])
    end

    def classifications
      @classification_tree_label = ClassificationTreeLabel.with_deleted.find(params[:id])
      @classification_aliases = @classification_tree_label.classification_aliases.where(internal: false).page(params[:page])

      if params[:modified_since]
        @classification_aliases = @classification_aliases.where(
          ClassificationAlias.arel_attribute(:updated_at).gteq(DateTime.parse(params[:modified_since]))
        ).order(:updated_at)
      end

      if params[:created_since]
        @classification_aliases = @classification_aliases.where(
          ClassificationAlias.arel_attribute(:created_at).gteq(DateTime.parse(params[:created_since]))
        ).order(:created_at)
      end

      if params[:deleted_since]
        @classification_aliases = @classification_aliases.with_deleted.where(
          ClassificationAlias.arel_attribute(:deleted_at).gteq(DateTime.parse(params[:deleted_since]))
        ).order(:deleted_at)
      end

      @classification_aliases = @classification_aliases.page(params[:page])
    end
  end
end