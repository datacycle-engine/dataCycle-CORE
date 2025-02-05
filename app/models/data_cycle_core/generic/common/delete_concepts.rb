# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DeleteConcepts
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.delete_data(
            utility_object: utility_object.tap { |obj| obj.mode = :full },
            iterator: method(:load_concepts).to_proc,
            data_processor: method(:process_concepts).to_proc,
            options:
          )
        end

        def self.load_concepts(filter_object:)
          filter_object.with_deleted.query
        end

        def self.process_concepts(utility_object:, raw_data:, locale:, options:)
          return if raw_data.blank?

          external_key_path = options.dig(:import, :external_key_path).split('.')
          external_keys = raw_data.filter_map { |data| data.dump[locale]&.dig(*external_key_path) }
          external_keys.map! { |key| [options.dig(:import, :external_key_prefix), key].join } if options.dig(:import, :external_key_prefix)

          to_destroy = DataCycleCore::ClassificationTree.includes(:sub_classification_alias).where(
            sub_classification_alias: { external_source_id: utility_object.external_source.id, external_key: external_keys }
          )

          to_destroy.destroy_all
        end
      end
    end
  end
end
