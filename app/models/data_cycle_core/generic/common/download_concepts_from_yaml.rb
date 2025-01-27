# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadConceptsFromYaml
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            iterator: method(:load_concepts_from_yaml).to_proc,
            data_id: method(:data_id).to_proc.curry[options.dig(:download, :external_id_hash_method)],
            data_name: method(:data_name).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        def self.load_concepts_from_yaml(options:, locale:, **_keyword_args)
          file_path = options.dig(:download, :file) || options.dig(:download, :file_path)
          raise ArgumentError, 'missing file path!' if file_path.nil?

          path = Rails.root.join(file_path)
          file = File.open(path)
          data = YAML.safe_load(file)

          data.map do |key, value|
            {
              'id' => key,
              'name' => value.is_a?(::Hash) ? value[locale] : value,
              'modifiedAt' => file.mtime.iso8601
            }.compact
          end
        end

        def self.data_id(external_id_hash_method, data)
          case external_id_hash_method
          when 'MD5'
            Digest::MD5.hexdigest(data['id'])
          else
            data['id']&.to_s
          end
        end

        def self.data_name(data)
          data['name']
        end
      end
    end
  end
end
