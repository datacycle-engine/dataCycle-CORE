# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Asset
        def self.file_name(**args)
          DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:name)&.to_s || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
        end

        def self.file_size(**args)
          DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:file_size)&.to_i || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
        end

        def self.file_format(computed_parameters:, data_hash:, key:, content:, **_args)
          DataCycleCore::Asset.find_by(id: computed_parameters&.first)&.try(:content_type) || data_hash&.[](key) || MiniMime.lookup_by_extension(data_hash['content_url']&.match(/.*\.(.*)/)&.[](1).to_s)&.content_type || content.try(key)
        end

        def self.file_type_classification(computed_parameters:, data_hash:, key:, content:, computed_definition:, **args)
          file_format_path = file_format(computed_parameters: computed_parameters, data_hash: data_hash, key: 'file_format', content: content, computed_definition: computed_definition, **args)&.split('/')

          return data_hash&.[](key) || content.try(key) || [] if file_format_path.blank?

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

        def self.content_url(**args)
          DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:file)&.try(:url) || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
        end

        def self.asset_url_with_transformation(**args)
          asset = DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)
          asset.try(args.dig(:computed_definition, 'compute', 'version') || 'original')&.url(args.dig(:computed_definition, 'compute', 'transformation')) || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
        end
      end
    end
  end
end
