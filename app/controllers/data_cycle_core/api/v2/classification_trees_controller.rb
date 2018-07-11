# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ClassificationTreesController < Api::V2::ApiBaseController
        def index
          @classification_tree_labels = ClassificationTreeLabel.where(internal: false)

          if permitted_params[:modified_since]
            @classification_tree_labels = @classification_tree_labels.where(
              ClassificationTreeLabel.arel_attribute(:updated_at).gteq(Time.zone.parse(permitted_params[:modified_since]))
            ).order(:updated_at)
          end

          if permitted_params[:created_since]
            @classification_tree_labels = @classification_tree_labels.where(
              ClassificationTreeLabel.arel_attribute(:created_at).gteq(Time.zone.parse(permitted_params[:created_since]))
            ).order(:created_at)
          end

          if permitted_params[:deleted_since]
            @classification_tree_labels = @classification_tree_labels.with_deleted.where(
              ClassificationTreeLabel.arel_attribute(:deleted_at).gteq(Time.zone.parse(permitted_params[:deleted_since]))
            ).order(:deleted_at)
          end

          @classification_tree_labels = apply_paging(@classification_tree_labels)
        end

        def show
          @classification_tree_label = ClassificationTreeLabel.find(permitted_params[:id])
        end

        def classifications
          page_params = permitted_params.fetch(:page, DEFAULT_PAGE_SETTINGS)
          @classification_tree_label = ClassificationTreeLabel.with_deleted.find(permitted_params[:id])
          @classification_aliases = @classification_tree_label.classification_aliases.where(internal: false).page(page_params[:number].to_i)

          if permitted_params[:modified_since]
            @classification_aliases = @classification_aliases.where(
              ClassificationAlias.arel_attribute(:updated_at).gteq(Time.zone.parse(permitted_params[:modified_since]))
            ).order(:updated_at)
          end

          if permitted_params[:created_since]
            @classification_aliases = @classification_aliases.where(
              ClassificationAlias.arel_attribute(:created_at).gteq(Time.zone.parse(permitted_params[:created_since]))
            ).order(:created_at)
          end

          if permitted_params[:deleted_since]
            @classification_aliases = @classification_aliases.with_deleted.where(
              ClassificationAlias.arel_attribute(:deleted_at).gteq(Time.zone.parse(permitted_params[:deleted_since]))
            ).order(:deleted_at)
          end

          @classification_aliases = apply_paging(@classification_aliases)
        end

        def permitted_parameter_keys
          super + [:id, :modified_since, :created_since, :deleted_since]
        end
      end
    end
  end
end
