# frozen_string_literal: true

require 'roo'

module DataCycleCore
  module Generic
    module Common
      # Enriches concepts stored in a Mongo collection with translations read from a
      # spreadsheet (xlsx/csv) and writes a per-locale, translated copy that can then be
      # imported with ImportConcepts.
      #
      # This is the reusable, connector-agnostic version of the "translation" download
      # step used by the OpenStreetMap-GeoJSON importer: for every processed locale it
      # reads the base concepts from `read_type` (always via `base_locale`, since the
      # source data usually only exists in the base locale), looks up the translated name
      # for the current locale in the spreadsheet and stores the enriched concept in
      # `source_type`. ImportConcepts then merges the names into `name_i18n` per locale.
      #
      # Configuration (all keys below `download:`):
      #   read_type:                 Mongo collection holding the base concepts (required)
      #   file:                      path/glob to the translation spreadsheet(s); ERB-enabled,
      #                              `locale` is in scope (e.g. "…/translations_<%= locale %>.xlsx")
      #   base_locale:               locale the base concepts are read from (default: processed locale)
      #   translation_key_path:      concept field a spreadsheet row is matched against (default: 'id')
      #   translation_key_column:    0-based index of the key column in the spreadsheet (default: 0)
      #   translation_locale_column: 0-based index of the value column; when omitted the column
      #                              whose header equals the locale is used (default),
      #                              falling back to the column right after the key column
      #   headers:                   whether the spreadsheet has a header row (default: true)
      #   separator:                 column separator for csv files (default: ';')
      #   source_filter:             optional additional Mongo match applied to the base concepts
      #
      # Copying a whole dump.<locale> used to carry the source collection's dc_step_priority into the
      # target as well. [#50666] strips it on the way in, which leaves the target claimed only if this
      # step configures a `priority:` of its own. Safe while no step may configure one above
      # DEFAULT_STEP_PRIORITY (enforced by ExternalSystemStepContract); centralising the default here
      # is what that cap buys us out of.
      module DownloadConceptTranslations
        # Download-strategy entry point invoked by the importer for each configured step.
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            iterator: method(:load_translated_concepts).to_proc,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        # NOTE: the auto-generated `source_filter:` (scoped to the processed locale) is
        # intentionally ignored – the base concepts are always read via `base_locale`.
        def self.load_translated_concepts(options:, locale:, **_keyword_args)
          read_type = options.dig(:download, :read_type)
          raise ArgumentError, 'missing read_type for translating concepts' if read_type.blank?

          base_locale = (options.dig(:download, :base_locale) || locale).to_s
          key_path = (options.dig(:download, :translation_key_path) || 'id').to_s
          translations = load_translations(options:, locale:)
          persistence = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: read_type)

          DataCycleCore::Generic::Collection2.with(persistence) do |mongo|
            mongo.collection.aggregate(
              [
                { '$match' => base_match(options:, base_locale:) },
                { '$replaceRoot' => { 'newRoot' => "$dump.#{base_locale}" } }
              ],
              allow_disk_use: true
            ).map { |concept| translate_concept(concept.to_h, translations, key_path) }
          end
        end

        # Mongo match for the base concepts, pinned to +base_locale+ plus an optional configured source_filter.
        def self.base_match(options:, base_locale:)
          match = {
            "dump.#{base_locale}" => { '$exists' => true },
            "dump.#{base_locale}.deleted_at" => { '$exists' => false }
          }

          source_filter = options.dig(:download, :source_filter)
          match.merge!(I18n.with_locale(base_locale) { source_filter.with_evaluated_values }) if source_filter.present?

          match
        end

        # Overrides the concept name with its translation for the current locale, keeping
        # every other base attribute (id, parent_id, uri, tree_label, …) untouched.
        # `external_system` and `dc_external_id` are dropped so they are rebuilt cleanly.
        def self.translate_concept(concept, translations, key_path)
          key = concept.dig(*key_path.split('.'))
          translation = translations[key.to_s]

          concept
            .except('external_system', 'dc_external_id')
            .merge('name' => translation.presence || concept['name'])
        end

        # Reads the configured spreadsheet(s) and returns a { key => translated name } hash for +locale+.
        def self.load_translations(options:, locale:)
          file_config = options.dig(:download, :file)
          raise ArgumentError, 'missing file for concept translations' if file_config.blank?

          key_column = options.dig(:download, :translation_key_column) || 0
          configured_value_column = options.dig(:download, :translation_locale_column)
          separator = options.dig(:download, :separator) || ';'
          has_headers = options.dig(:download, :headers)
          has_headers = true if has_headers.nil?

          translations = {}

          file_paths(file_config, locale).each do |path|
            Roo::Spreadsheet.open(path, csv_options: { col_sep: separator }).each_with_pagename do |_page, sheet|
              value_column = configured_value_column
              header_seen = false

              sheet.each do |row|
                if has_headers && !header_seen
                  header_seen = true
                  value_column ||= row.index { |cell| cell.to_s.strip.casecmp?(locale.to_s) }
                  next
                end

                value_column ||= key_column + 1
                next if row.blank?

                key = row[key_column].to_s.strip
                value = row[value_column].to_s.strip
                next if key.blank? || value.blank?

                translations[key] = value
              end
            end
          end

          translations
        end

        # Resolves the configured file glob(s) for +locale+, rendering ERB (+locale+ is in scope).
        def self.file_paths(file_config, locale)
          Array.wrap(file_config).flat_map do |file|
            rendered = ERB.new(file.to_s).result(binding)
            Dir[Rails.root.join(rendered).to_s]
          end
        end

        # External id of a yielded concept, used as the mongo external_id.
        def self.data_id(data)
          data['id']
        end

        # Name of a yielded concept, used as a fallback when the stored name is blank.
        def self.data_name(data)
          data['name']
        end
      end
    end
  end
end
