# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelIdentityServer
      module ImportClaims
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label),
            method(:load_root_classifications).to_proc,
            method(:load_child_classifications).to_proc,
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, locale, _options)
          mongo_item.where("dump.#{locale}.claims": { '$exists' => true })
            .map { |m|
              m.dump.dig(locale, 'claims')&.map do |k, _v|
                if k.present?
                  {
                    'dump' => {
                      locale.to_s => {
                        'name' => k
                      }
                    }
                  }.with_indifferent_access
                end
              end
            }.flatten.compact.uniq
        end

        def self.load_child_classifications(mongo_item, parent_category_data, locale)
          mongo_item.where("dump.#{locale}.claims.#{parent_category_data['name']}": { '$exists' => true })
            .map { |m|
              m.dump.dig(locale, 'claims')&.slice(parent_category_data['name'])&.map do |k, v|
                Array(v).map do |value|
                  next if value.blank?
                  {
                    'dump' => {
                      locale.to_s => {
                        'name' => value,
                        'parent' => k
                      }
                    }
                  }.with_indifferent_access
                end
              end
            }.flatten.compact.uniq
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, _options = {})
          DataCycleCore::Classification
            .find_by(external_source_id: external_source_id, external_key: "CLAIM:#{raw_data['parent']}")
            .try(:primary_classification_alias)
        end

        def self.extract_data(_options, raw_data)
          {
            external_key: "CLAIM:#{raw_data['name']}",
            name: raw_data['name']
          }
        end
      end
    end
  end
end
