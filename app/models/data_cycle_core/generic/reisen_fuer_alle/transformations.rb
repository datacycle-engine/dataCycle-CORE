# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_icon
          t(:add_field, 'external_key', ->(s) { ['reisen-fuer-alle.de - icon', s.dig('name')].join(' - ') })
          .>> t(:add_field, 'content_url', ->(s) { s.dig('url') })
          .>> t(:add_field, 'thumbnail_url', ->(s) { s.dig('url') })
        end

        def self.to_rating(external_source_id)
          t(:rename_keys, { 'uuid' => 'external_key' })
          .>> t(:add_links, 'image', DataCycleCore::Thing, external_source_id, ->(s) { generate_icon_external_keys(s) })
          .>> t(:add_field, 'name', ->(s) { s.dig('base_data', 'name_de') })
          .>> t(:unwrap, 'public_pdf') # ['url_for_allergic_de', 'url_for_deaf_de', 'url_for_generations_de', 'url_for_mental_de', 'url_for_visual_de', 'url_for_walking_de', 'url_for_wheelchair_de']
          .>> t(:rename_keys, { 'url_for_allergic_de' => 'allergic', 'url_for_deaf_de' => 'deaf', 'url_for_generations_de' => 'generations', 'url_for_mental_de' => 'mental', 'url_for_visual_de' => 'visual', 'url_for_walking_de' => 'walking', 'url_for_wheelchair_de' => 'wheelchair' })
          .>> t(:nest, 'public_pdf', ['allergic', 'deaf', 'generations', 'mental', 'visual', 'walking', 'wheelchair'])
          .>> t(:unwrap, 'short_report')
          .>> t(:rename_keys, { 'deaf_and_partially_deaf_de' => 'deaf', 'mental_de' => 'mental', 'visual_and_partially_visual_de' => 'visual', 'wheelchair_and_walking_de' => 'walking' })
          .>> t(:nest, 'short_report', ['deaf', 'mental', 'visual', 'walking'])
          .>> t(:unwrap, 'certificate_data')
          .>> t(:nest, 'certification_period', ['certified_from', 'certified_to'])
          .>> t(:unwrap, 'certificate_type')
          .>> t(:rename_keys, { 'label_de' => 'designation', 'icon_url_de' => 'icon' })
          .>> t(:nest, 'certification_type', ['designation', 'key', 'icon'])
          .>> t(:add_links, 'licence_owner', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('licence_owner'))&.map { |i| "reisen-fuer-alle.de - Lizenznehmer - #{i}" } })
          .>> t(:add_field, 'certificate_classification', ->(s) { add_classifications(s) })
          .>> t(:add_field, 'linked_thing', ->(s) { add_external_links(s.slice('feratel', 'outdoor_active')) })
          .>> t(:add_links, 'search_criteria', DataCycleCore::Classification, external_source_id,
                lambda { |s|
                  Array.wrap(s.dig('grouped_search_criteria')).map { |g|
                    g['search_criteria']
                  }.flatten.map do |c|
                    Constants::SEARCH_CRITERIA_CLASSIFICATION_PREFIX + c['id']
                  end || []
                })
          .>> t(:universal_classifications, ->(s) { s.dig('search_criteria') })
          .>> t(:reject_keys, ['base_data', 'deaf', 'mental', 'partially_deaf', 'partially_visual', 'visual', 'walking', 'wheelchair'])
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

        def self.get_classification_id(leaf, parent)
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

        def self.add_external_links(data)
          return [] if data.blank?
          linked_items = []
          linked_items.push(t(:find_thing_ids).call(**data['feratel'].symbolize_keys).first) if data.dig('feratel').present?
          linked_items.push(t(:find_thing_ids).call(**data['outdoor_active'].symbolize_keys).first) if data.dig('outdoor_active').present?
          linked_items.compact
        end

        def self.generate_icon_external_keys(data)
          external_keys = []
          if data.dig('certificate_data', 'certificate_type').present?
            type_key = ['reisen-fuer-alle.de - icon', data.dig('certificate_data', 'certificate_type', 'label_de')].join(' - ')
            external_keys.push(type_key)
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
