# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ClassificationTreesController < ::DataCycleCore::Api::V4::ApiBaseController
        before_action :prepare_url_parameters

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

          if @classification_id.present?
            @classification_aliases = DataCycleCore::ClassificationAlias.where(id: @classification_id) # .with_descendants
          else
            # @classification_aliases = DataCycleCore::ClassificationAlias.for_tree(@classification_tree_label.name)
            @classification_aliases = @classification_tree_label.classification_aliases
          end

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

          @classification_aliases = apply_paging(@classification_aliases.order(:internal_name))
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
          @include_parameters = parse_tree_params(permitted_params.dig(:include))
          @fields_parameters = parse_tree_params(permitted_params.dig(:fields))
          @field_filter = @fields_parameters.present?
          @language = permitted_params.dig(:language) || I18n.available_locales.first.to_s
          @api_subversion = permitted_params.dig(:api_subversion) if DataCycleCore.main_config.dig(:api, :v4, :subversions)&.include?(permitted_params.dig(:api_subversion))
          @api_version = 4
        end

        def permitted_parameter_keys
          super + [:id, :include, :fields, :format, :language, :classification_id, { filter: [:modified_since, :created_since, :deleted_since] }]
        end
      end
    end
  end
end
