# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_icon
          t(:map_value, 'name', ->(v) { v || 'No certification' })
          .>> t(:map_value, 'description', ->(v) { v || 'missing' })
          .>> t(:add_field, 'external_key', ->(s) { ['reisen-fuer-alle.de - icon', s.dig('name')].join(' - ') })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('url') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('url') })
        end

        def self.to_rating(external_source_id, lang)
          t(:rename_keys, { 'uuid' => 'external_key' })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { generate_icon_external_keys(s, lang) })
          .>> t(:add_field, 'name', ->(s) { s.dig('base_data', "name_#{lang}") })
          .>> t(:map_value, 'public_pdf', ->(s) { transform_pdfs(s, lang) })
          .>> t(:map_value, 'short_reports', ->(s) { transform_short_reports(s, lang) })
          .>> t(:add_links, 'search_criteria', DataCycleCore::Classification, external_source_id,
                lambda { |s|
                  Array.wrap(s.dig('grouped_search_criteria')).map { |g|
                    g['search_criteria']
                  }.flatten.map do |c|
                    Constants::SEARCH_CRITERIA_CLASSIFICATION_PREFIX + c['id']
                  end || []
                })
          .>> t(:universal_classifications, ->(s) { s.dig('search_criteria') + get_certification_type(s.dig('certificate_data', 'certificate_type'), lang) })
          .>> t(:unwrap, 'certificate_data')
          .>> t(:nest, 'certification_period', ['certified_from', 'certified_to'])
          .>> t(:map_value, 'certificate_type', ->(s) { transform_certificate_type(s, lang) })
          .>> t(:add_links, 'licence_owner', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('licence_owner'))&.map { |i| "reisen-fuer-alle.de - Lizenznehmer - #{i}" } })
          .>> t(:add_field, 'certificate_classification', ->(s) { add_classifications(s) })
          .>> t(:add_field, 'linked_thing', ->(s) { add_external_links(s.slice('feratel', 'outdoor_active')) })
          .>> t(:reject_keys, ['base_data', 'deaf', 'mental', 'partially_deaf', 'partially_visual', 'visual', 'walking', 'wheelchair'])
        end

        def self.transform_pdfs(s, lang)
          return nil if s.nil?
          {
            'short_report' => s.dig('url_for_short_report', lang),
            'allergic' => s.dig('url_for_allergic', lang),
            'deaf' => s.dig('url_for_deaf', lang),
            'generations' => s.dig('url_for_generations', lang),
            'mental' => s.dig('url_for_mental', lang),
            'visual' => s.dig('url_for_visual', lang),
            'walking' => s.dig('url_for_walking', lang),
            'wheelchair' => s.dig('url_for_wheelchair', lang)
          }
        end

        def self.transform_short_reports(s, lang)
          return nil if s.nil?
          {
            'deaf' => s.dig("deaf_and_partially_deaf_#{lang}"),
            'mental' => s.dig("mental_#{lang}"),
            'visual' => s.dig("visual_and_partially_visual_#{lang}"),
            'walking' => s.dig("wheelchair_and_walking_#{lang}")
          }
        end

        def self.transform_certificate_type(s, lang)
          {
            'designation' => s.dig("label_#{lang}"),
            'key' => s.dig('key'),
            'icon' => s.dig("icon_url_#{lang}")
          }
        end

        def self.add_classifications(data)
          convert_topic_to_classification_name = {
            'deaf' => 'Gehörlose',
            'mental' => 'Kognitiv Beeinträchtigte',
            'partially_deaf' => 'Hörbehinderte',
            'partially_visual' => 'Sehbehinderte',
            'visual' => 'Blinde',
            'walking' => 'Gehbehinderte',
            'wheelchair' => 'Rollstuhlfahrer'
          }
          convert_level = {
            'full' => 'barrierefrei',
            'info' => 'teilweise barrierefrei'
          }

          result = ['deaf', 'mental', 'partially_deaf', 'partially_visual', 'visual', 'walking', 'wheelchair'].map { |topic|
            next if data.dig(topic, 'level') == 'none'
            get_classification_id(convert_level[data.dig(topic, 'level')], convert_topic_to_classification_name[topic])
          }.compact
          result
        end

        def self.get_certification_type(type_hash, lang)
          return [] if type_hash.blank?
          ca = DataCycleCore::ClassificationAlias.for_tree('reisen-fuer-alle.de - Zertifizierungstypen').with_name(type_hash.dig("label_#{lang}")).first
          if type_hash.dig("icon_url_#{lang}").nil?
            Array.wrap(ca.primary_classification_id)
          else
            Array.wrap(ca.sub_classification_alias.find_by(name: type_hash.dig('key')).primary_classification_id)
          end
        end

        def self.get_classification_id(leaf, parent)
          I18n.with_locale(:de) do
            parent_class = DataCycleCore::ClassificationAlias.for_tree('reisen-fuer-alle.de - Zertifikate').find_by(name: parent)
            raise "reise-fuer-all.de importer: could not find classification_alias for #{parent} in tree (reisen-fuer-alle.de - Zertifikate)" if parent.blank?
            class_alias = DataCycleCore::ClassificationAlias
              .joins(:classification_tree)
              .find_by(
                classification_aliases: { name: leaf },
                classification_trees: {
                  parent_classification_alias_id: parent_class.try(:id)
                }
              )
            raise "reise-fuer-all.de importer: could not find classification_alias for #{leaf} in tree (reisen-fuer-alle.de - Zertifikate) with parent_classification_alias #{parent}" if class_alias.blank?
            class_alias.primary_classification.id
          end
        end

        def self.add_external_links(data)
          return [] if data.blank?
          linked_items = []
          data['feratel']&.each { |fdata| linked_items.push(t(:find_thing_ids).call(**fdata.symbolize_keys).first) }
          linked_items.push(t(:find_thing_ids).call(**data['outdoor_active'].symbolize_keys).first) if data.dig('outdoor_active').present?
          linked_items.compact
        end

        def self.generate_icon_external_keys(data, lang)
          external_keys = []
          if data.dig('certificate_data', 'certificate_type').present?
            ca = DataCycleCore::ClassificationAlias.for_tree('reisen-fuer-alle.de - Zertifizierungstypen').with_name(data.dig('certificate_data', 'certificate_type', "label_#{lang}")).first
            ca.available_locales.each do |locale|
              I18n.with_locale(locale) do
                type_key = ['reisen-fuer-alle.de - icon', ca.name].join(' - ')
                external_keys.push(type_key)
              end
            end
          end

          ['deaf', 'mental', 'partiall_deaf', 'partially_visual', 'visual', 'walking', 'wheelchair'].each do |kind|
            next if data.dig('certificate_data', kind, 'level') == 'none'
            next if data.dig('certificate_data', kind, 'icon_url').blank?
            icon_key = ['reisen-fuer-alle.de - icon', kind, data.dig('certificate_data', kind, 'level')].join(' - ')
            external_keys.push(icon_key)
          end
          external_keys
        end
      end
    end
  end
end
