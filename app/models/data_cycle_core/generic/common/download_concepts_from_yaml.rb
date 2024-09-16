# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadConceptsFromYaml
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_concepts_from_data(
            download_object: utility_object,
            iterator: method(:load_concepts_from_yaml).to_proc,
            data_id: method(:data_id).to_proc.curry[options.dig(:download, :external_id_hash_method)],
            data_name: method(:data_name).to_proc,
            options:
          )
        end

        def self.credentials?
          false
        end

        def self.load_concepts_from_yaml(options:, lang:, **_keyword_args)
          raise ArgumentError, 'missing file path!' if options.dig(:download, :file).nil?

          path = Rails.root.join(options.dig(:download, :file))
          file = File.open(path)
          data = YAML.safe_load(file)

          data.map do |key, value|
            {
              'id' => key,
              'name' => value.is_a?(::Hash) ? value.dig(lang) : value,
              'modifiedAt' => file.mtime.iso8601
            }.compact
          end
        end

        def self.data_id(external_id_hash_method, data)
          case external_id_hash_method
          when 'MD5'
            Digest::MD5.hexdigest(data.dig('id'))
          else
            data.dig('id')&.to_s
          end
        end

        def self.data_name(data)
          data.dig('name')
        end
      end
    end
  end
end
