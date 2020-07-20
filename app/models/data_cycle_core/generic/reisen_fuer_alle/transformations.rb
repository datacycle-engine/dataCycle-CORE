# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_rating(external_source_id)
          t(:rename_keys, { 'uuid' => 'external_key' })
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
          linked_items.push(DataCycleCore::Thing.find_by(**data['feratel'].symbolize_keys)&.id) if data.dig('feratel').present?
          linked_items.push(DataCycleCore::Thing.find_by(**data['outdoor_active'].symbolize_keys)&.id) if data.dig('outdoor_active').present?
          linked_items.compact
        end
      end
    end
  end
end
