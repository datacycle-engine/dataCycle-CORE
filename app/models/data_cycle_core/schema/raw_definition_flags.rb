# frozen_string_literal: true

module DataCycleCore
  class Schema
    # Single source for the dataCycle-specific property markers that are read
    # straight from a raw property definition (NOT from the generated OpenAPI
    # fragment). Shared by PropertyPresenter (the /schema detail page, which is the
    # OpenAPI contract) and XlsxPropertyPresenter (the /schema XLSX export) so the
    # two /schema surfaces can never label the same property differently (#50201).
    #
    # Only the flags both surfaces derive identically from the raw definition live
    # here. Surface-specific markers stay on their presenter: `geographic` /
    # `virtual` / `overlay` (detail only) and `recursive` (XLSX tree walk only).
    # Cardinality is deliberately NOT shared — the detail page derives it from the
    # OpenAPI fragment (FragmentReader) while the XLSX reads the raw type; unifying
    # those two sources is the separate #50201 §2.2 question.
    module RawDefinitionFlags
      module_function

      # A property is translated when it is stored per-locale: either in a
      # translated jsonb field, or in a `column`-storage key that actually lives
      # on the translated thing_translations table (e.g. the built-in `name`
      # column). `key` is the property's own key (raw schema key / api_name).
      def translated?(definition, key)
        definition['storage_location'] == 'translated_value' ||
          (definition['storage_location'] == 'column' &&
            DataCycleCore::Thing::Translation.column_names.include?(key.to_s))
      end

      # A property linked to a classification tree.
      def classification?(definition)
        definition['type'] == 'classification'
      end

      # An embedded content (nested object stored inline on the parent).
      def embedded?(definition)
        definition['type'] == 'embedded'
      end

      # A linked content (reference to another top-level content).
      def linked?(definition)
        definition['type'] == 'linked'
      end

      # Fulltext-searchable (the raw `search` flag).
      def fulltext?(definition)
        definition['search'] == true
      end

      # The classification tree label declared on the definition (nil when none).
      def tree_label(definition)
        definition['tree_label']
      end
    end
  end
end
