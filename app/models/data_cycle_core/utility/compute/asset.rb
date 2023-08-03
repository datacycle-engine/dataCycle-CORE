# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Asset
        def self.file_name(computed_parameters:, **_args)
          DataCycleCore::Asset.find_by(id: computed_parameters.values.first)&.try(:name)&.to_s
        end

        def self.file_size(computed_parameters:, **_args)
          DataCycleCore::Asset.find_by(id: computed_parameters.values.first)&.try(:file_size)&.to_i
        end

        def self.file_format(computed_parameters:, data_hash:, **_args)
          DataCycleCore::Asset.find_by(id: computed_parameters.values.first)&.try(:content_type) || MiniMime.lookup_by_extension(data_hash['content_url']&.match(/.*\.(.*)/)&.[](1).to_s)&.content_type
        end

        def self.file_type_classification(computed_parameters:, computed_definition:, **_args)
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

        def self.content_url(computed_parameters:, **_args)
          asset = DataCycleCore::Asset.find_by(id: computed_parameters.values.first)
          return unless asset&.file&.attached?
          Rails.application.routes.url_helpers.rails_storage_proxy_url(asset.file, host: Rails.application.config.asset_host)
        end

        def self.asset_url_with_transformation(computed_parameters:, computed_definition:, **_args)
          asset = DataCycleCore::Asset.find_by(id: computed_parameters.values.first)

          asset.try(:dynamic, computed_definition.dig('compute', 'transformation'))&.url
        end
      end
    end
  end
end
