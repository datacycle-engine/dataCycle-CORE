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
          .>> t(:add_links, 'certification_deaf', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('deaf', 'level'))&.map { |i| "reisen-fuer-alle.de - Zertifikat - Gehörlos - #{i}" } })
          .>> t(:add_links, 'certification_mental', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('mental', 'level'))&.map { |i| "reisen-fuer-alle.de - Zertifikat - Kognitiv - #{i}" } })
          .>> t(:add_links, 'certification_partially_deaf', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('partially_deaf', 'level'))&.map { |i| "reisen-fuer-alle.de - Zertifikat - Hörbehinderung - #{i}" } })
          .>> t(:add_links, 'certification_partially_visual', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('partially_visual', 'level'))&.map { |i| "reisen-fuer-alle.de - Zertifikat - Sehbehinderung - #{i}" } })
          .>> t(:add_links, 'certification_visual', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('visual', 'level'))&.map { |i| "reisen-fuer-alle.de - Zertifikat - Blind - #{i}" } })
          .>> t(:add_links, 'certification_walking', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('walking', 'level'))&.map { |i| "reisen-fuer-alle.de - Zertifikat - Gehbehinderung - #{i}" } })
          .>> t(:add_links, 'certification_wheelchair', DataCycleCore::Classification, external_source_id, ->(s) { Array.wrap(s.dig('wheelchair', 'level'))&.map { |i| "reisen-fuer-alle.de - Zertifikat - Rollstuhl - #{i}" } })
          .>> t(:add_field, 'linked_thing', ->(s) { add_external_links(s.slice('feratel', 'outdoor_active')) })
          .>> t(:reject_keys, ['base_data', 'deaf', 'mental', 'partially_deaf', 'partially_visual', 'visual', 'walking', 'wheelchair'])
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
