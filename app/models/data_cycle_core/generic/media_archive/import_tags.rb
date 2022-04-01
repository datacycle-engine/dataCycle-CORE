# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      module ImportTags
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label),
            method(:load_root_classifications).to_proc,
            ->(_, _, _) { [] },
            ->(_, _, _) { nil },
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, _locale, _options)
          mongo_item.where(:_id.ne => nil)
        end

        def self.extract_data(options, raw_data)
          # TODO: remove after all tags are migrated
          classification = DataCycleCore::Classification.find_by(external_source_id: options.dig(:external_source_id), external_key: "#{options.dig(:import, :external_id_prefix)}#{raw_data['name']}")

          if classification.present?
            classification.external_key = "#{options.dig(:import, :external_id_prefix)}#{raw_data['id']}"
            classification.save(touch: false)
          end

          {
            external_key: "#{options.dig(:import, :external_id_prefix)}#{raw_data['id']}",
            name: raw_data['name']
          }
        end
      end
    end
  end
end
