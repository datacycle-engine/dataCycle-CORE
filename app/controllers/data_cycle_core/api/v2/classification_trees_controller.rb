# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ClassificationTreesController < Api::V2::ApiBaseController
        before_action :prepare_url_parameters

        ALLOWED_INCLUDE_PARAMETERS = ['linked', 'translations'].freeze
        ALLOWED_MODE_PARAMETERS = ['compact', 'minimal'].freeze

        def index
          @classification_tree_labels = ClassificationTreeLabel.where(internal: false)

          if permitted_params.dig(:filter, :modified_since)
            @classification_tree_labels = @classification_tree_labels.where(
              ClassificationTreeLabel.arel_attribute(:updated_at).gteq(Time.zone.parse(permitted_params.dig(:filter, :modified_since)))
            ).order(:updated_at)
          end

          if permitted_params.dig(:filter, :created_since)
            @classification_tree_labels = @classification_tree_labels.where(
              ClassificationTreeLabel.arel_attribute(:created_at).gteq(Time.zone.parse(permitted_params.dig(:filter, :created_since)))
            ).order(:created_at)
          end

          if permitted_params.dig(:filter, :deleted_since)
            @classification_tree_labels = @classification_tree_labels.with_deleted.where(
              ClassificationTreeLabel.arel_attribute(:deleted_at).gteq(Time.zone.parse(permitted_params.dig(:filter, :deleted_since)))
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
          @classification_aliases = @classification_tree_label.classification_aliases.page(page_params[:number].to_i)

          if permitted_params.dig(:filter, :modified_since)
            @classification_aliases = @classification_aliases.where(
              ClassificationAlias.arel_attribute(:updated_at).gteq(Time.zone.parse(permitted_params.dig(:filter, :modified_since)))
            ).order(:updated_at)
          end

          if permitted_params.dig(:filter, :created_since)
            @classification_aliases = @classification_aliases.where(
              ClassificationAlias.arel_attribute(:created_at).gteq(Time.zone.parse(permitted_params.dig(:filter, :created_since)))
            ).order(:created_at)
          end

          if permitted_params.dig(:filter, :deleted_since)
            @classification_aliases = @classification_aliases.with_deleted.where(
              ClassificationAlias.arel_attribute(:deleted_at).gteq(Time.zone.parse(permitted_params.dig(:filter, :deleted_since)))
            ).order(:deleted_at)
          end

          @classification_aliases = apply_paging(@classification_aliases)
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
          @include_parameters = (permitted_params.dig(:include)&.split(',') || []).select { |v| ALLOWED_INCLUDE_PARAMETERS.include?(v) }.sort
          @mode_parameters = (permitted_params.dig(:mode)&.split(',') || []).select { |v| ALLOWED_MODE_PARAMETERS.include?(v) }.sort
          @language = permitted_params.dig(:language) || I18n.available_locales.first.to_s
        end

        def permitted_parameter_keys
          super + [:id, :include, :mode, { filter: [:modified_since, :created_since, :deleted_since] }]
        end
      end
    end
  end
end
