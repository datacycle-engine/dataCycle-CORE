# frozen_string_literal: true

module DataCycleCore
  module Api
    module V3
      class ClassificationTreesController < ::DataCycleCore::Api::V3::ApiBaseController
        before_action :prepare_url_parameters

        ALLOWED_INCLUDE_PARAMETERS = ['linked', 'translations'].freeze
        ALLOWED_MODE_PARAMETERS = ['compact', 'minimal', 'strict'].freeze

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
          @classification_tree_label = ClassificationTreeLabel.with_deleted.find(permitted_params[:id])
          @classification_id = permitted_params[:classification_id] || nil

          if @classification_id.present? && @mode_parameters.include?('strict')
            @classification_aliases = DataCycleCore::ClassificationAlias.find(@classification_id).sub_classification_alias
          elsif @mode_parameters.include?('strict')
            @classification_aliases = @classification_tree_label.classification_aliases.includes(:parent_classification_alias).where(classification_trees: { parent_classification_alias_id: nil })
          elsif @classification_id.present?
            @classification_aliases = DataCycleCore::ClassificationAlias.find(@classification_id).descendants
          else
            @classification_aliases = @classification_tree_label.classification_aliases
          end

          if permitted_params.dig(:filter, :modified_since)
            @classification_aliases = @classification_aliases.where(
              ClassificationAlias.arel_attribute(:updated_at).gteq(Time.zone.parse(permitted_params.dig(:filter, :modified_since)))
            ).reorder(nil).order(:updated_at)
          end

          if permitted_params.dig(:filter, :created_since)
            @classification_aliases = @classification_aliases.where(
              ClassificationAlias.arel_attribute(:created_at).gteq(Time.zone.parse(permitted_params.dig(:filter, :created_since)))
            ).reorder(nil).order(:created_at)
          end

          if permitted_params.dig(:filter, :deleted_since)
            @classification_aliases = @classification_aliases.with_deleted.where(
              ClassificationAlias.arel_attribute(:deleted_at).gteq(Time.zone.parse(permitted_params.dig(:filter, :deleted_since)))
            ).reorder(nil).order(:deleted_at)
          end

          @classification_aliases = apply_paging(@classification_aliases.order(:internal_name))
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.except('format')
          @include_parameters = (permitted_params.dig(:include)&.split(',') || []).select { |v| ALLOWED_INCLUDE_PARAMETERS.include?(v) }.sort
          @mode_parameters = (permitted_params.dig(:mode)&.split(',') || []).select { |v| ALLOWED_MODE_PARAMETERS.include?(v) }.sort
          @language = permitted_params.dig(:language) || I18n.available_locales.first.to_s
          @api_subversion = permitted_params.dig(:api_subversion) if DataCycleCore.main_config.dig(:api, :v3, :subversions)&.include?(permitted_params.dig(:api_subversion))
          @api_version = 3
        end

        def permitted_parameter_keys
          super + [:id, :include, :mode, :language, :classification_id, { filter: [:modified_since, :created_since, :deleted_since] }]
        end
      end
    end
  end
end
