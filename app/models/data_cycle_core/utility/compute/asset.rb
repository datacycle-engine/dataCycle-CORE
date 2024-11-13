# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Asset
        extend DataCycleCore::Engine.routes.url_helpers

        class << self
          def url_options
            Rails.application.config.action_mailer.default_url_options
          end

          def file_name(computed_parameters:, **_args)
            DataCycleCore::Asset.find_by(id: computed_parameters.values.first)&.try(:name)&.to_s
          end

          def file_size(computed_parameters:, **_args)
            DataCycleCore::Asset.find_by(id: computed_parameters.values.first)&.try(:file_size)&.to_i
          end

          def file_format(computed_parameters:, data_hash:, **_args)
            DataCycleCore::Asset.find_by(id: computed_parameters.values.first)&.try(:content_type) || MiniMime.lookup_by_extension(data_hash['content_url']&.match(/.*\.(.*)/)&.[](1).to_s)&.content_type
          end

          def file_type_classification(computed_parameters:, computed_definition:, **_args)
            file_format_path = computed_parameters.values.first&.split('/')

            return [] if file_format_path.blank?

            classification_alias_candidate = DataCycleCore::ClassificationAlias
              .for_tree(computed_definition&.dig('tree_label'))
              .includes(:classification_alias_path)
              .where(classification_alias_paths: { full_path_names: file_format_path.reverse.append(computed_definition&.dig('tree_label')) })
              .primary_classifications
              .limit(1)
              .pluck(:id)

            return Array.wrap(classification_alias_candidate) if classification_alias_candidate.present?

            tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: computed_definition&.dig('tree_label'))

            Array.wrap(tree_label&.create_classification_alias(*Array.wrap(file_format_path))&.primary_classification&.id)
          end

          def content_url(content:, computed_parameters:, **_args)
            asset = DataCycleCore::Asset.find_by(id: computed_parameters.values.first)

            return if asset.nil?

            local_blob_url(id: content.id, file: asset.filename)
          end

          def content_url_from_slug(content:, computed_parameters:, **_args)
            asset = DataCycleCore::Asset.find_by(id: computed_parameters['asset'])

            return if asset.nil?

            slug = if I18n.locale == content.first_available_locale(:de)
                     computed_parameters['slug']
                   else
                     I18n.with_locale(content.first_available_locale(:de)) do
                       content.try(:slug) || computed_parameters['slug']
                     end
                   end

            local_blob_url(id: "#{slug}.#{asset.file_extension}")
          end

          def asset_url_with_transformation(computed_parameters:, computed_definition:, **_args)
            asset = DataCycleCore::Asset.find_by(id: computed_parameters.values.first)

            asset.try(:dynamic, computed_definition.dig('compute', 'transformation'))&.url
          end
        end
      end
    end
  end
end
