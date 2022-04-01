# frozen_string_literal: true

module DataCycleCore
  module Generic
    module JetTicket
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_event_series(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('Name1') })
          .>> t(:add_field, 'external_key', ->(s) { ['JetTicket - EventSeriesID: ', s.dig('EventSetID')].join })
          .>> t(:add_links, 'sub_event', DataCycleCore::Thing, external_source_id, ->(s) { DataCycleCore::Thing.where(external_source_id: external_source_id, template_name: 'Event').where('external_key ILIKE ?', "#{s.dig('external_key')}%").pluck(:external_key) })
          .>> t(:strip_all)
        end

        def self.to_event(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'name', ->(s) { s.dig('Name1') })
          .>> t(:add_field, 'description', ->(*) { '' }) # delete former s.dig('Comment')
          .>> t(:add_field, 'external_key', ->(s) { ['JetTicket - EventSeriesID: ', s.dig('EventSetID'), ' - ', s.dig('Name1')].join })
          .>> t(:add_field, 'event_schedule', ->(s) { Array.wrap(event_schedule(s)) })
          .>> t(:add_links, 'super_event', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(['JetTicket - EventSeriesID: ', s.dig('EventSetID')].join) })
          .>> t(:add_links, 'organizer', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s&.dig('EventManager', 'EventManagerID'))&.map { |i| "JetTicket - EventManagerID: #{i}" } })
          .>> t(:add_links, 'content_location', DataCycleCore::Thing, external_source_id, ->(s) { Array.wrap(s&.dig('Venue', 'VenueID'))&.map { |i| "JetTicket - VenueID: #{i}" } })
          .>> t(:add_field, 'dc_potential_action', ->(s) { parse_potential_action(s, external_source_id) })
          .>> t(:universal_classifications, ->(s) { event_status(s.dig('Status')) })
          .>> t(:universal_classifications, ->(s) { event_flags(s.dig('EventFlags')) })
          .>> t(:universal_classifications, ->(s) { [s.dig('EventType', 'EventTypeID')].compact.map { |i| 'JetTicket - EventTyp - ' + i.to_s }.map { |i| DataCycleCore::Classification.find_by(external_source_id: external_source_id, external_key: i)&.id }.compact })
          .>> t(:universal_classifications, ->(s) { [s.dig('EventType2', 'EventTypeID')].compact.map { |i| 'JetTicket - EventGattung - ' + i.to_s }.map { |i| DataCycleCore::Classification.find_by(external_source_id: external_source_id, external_key: i)&.id }.compact })
          .>> t(:strip_all)
        end

        def self.parse_potential_action(data, external_source_id)
          url_translator = {
            '9' => 'Bregenz',
            '13' => 'Dornbirn',
            '14' => 'Goetzis',
            '15' => 'Feldkirch',
            '16' => 'Landestheater',
            '17' => 'Bludenz',
            '18' => 'Symphonieorchester'
          }
          event_set_id = data.dig('EventSetID')
          Array.wrap(data.dig('Releases', 'Release').detect { |i| i.dig('ReleaseID')&.in?(url_translator.keys) })
            .map { |i|
              action = {}
              action_id = DataCycleCore::Thing.find_by(external_key: "JetTicket OrderAction:#{data.dig('EventID')}", external_source_id: external_source_id)&.id
              action['id'] = action_id if action_id.present?
              action['name'] = 'zum WEBSHOP'
              action['action_type'] = Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name('ActionTypes', 'Bestellen'))
              action['external_key'] = "JetTicket OrderAction:#{data.dig('EventID')}"
              action['url'] = "https://webshop.events-vorarlberg.at/#{url_translator[i.dig('ReleaseID')]}/Events?eventsetid=#{event_set_id}"
              action
            }.compact || []
        end

        def self.to_organizer(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { 'JetTicket - EventManagerID: ' + s.dig('EventManagerID') })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('Address', 'Street') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('Address', 'Postal') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('Address', 'City') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('Address', 'CountryCode') })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_field, 'country_code', ->(s) { convert_country_code(s.dig('Address', 'CountryCode'), external_source_id) })
          .>> t(:add_field, 'contact_name', ->(s) { s.dig('Address', 'Name2') unless s.dig('Address', 'Name1') == s.dig('Address', 'Name2') })
          .>> t(:add_field, 'telephone', ->(s) { s.dig('Address', 'Mobile') || s.dig('Address', 'Phone') })
          .>> t(:add_field, 'fax_number', ->(s) { s.dig('Address', 'Fax') })
          .>> t(:add_field, 'email', ->(s) { s.dig('Address', 'EMail') })
          .>> t(:add_field, 'url', ->(s) { s.dig('Address', 'URL') })
          .>> t(:nest, 'contact_info', ['contact_name', 'telephone', 'fax_number', 'email', 'url'])
          .>> t(:add_field, 'name', ->(s) { s.dig('Address', 'Name1') })
          .>> t(:strip_all)
        end

        def self.to_place(external_source_id)
          t(:stringify_keys)
          .>> t(:add_field, 'external_key', ->(s) { 'JetTicket - VenueID: ' + s.dig('VenueID') })
          .>> t(:add_field, 'street_address', ->(s) { s.dig('Address', 'Street') })
          .>> t(:add_field, 'postal_code', ->(s) { s.dig('Address', 'Postal') })
          .>> t(:add_field, 'address_locality', ->(s) { s.dig('Address', 'City') })
          .>> t(:add_field, 'address_country', ->(s) { s.dig('Address', 'CountryCode') })
          .>> t(:nest, 'address', ['street_address', 'postal_code', 'address_locality', 'address_country'])
          .>> t(:add_field, 'country_code', ->(s) { convert_country_code(s.dig('Address', 'CountryCode'), external_source_id) })
          .>> t(:add_field, 'contact_name', ->(s) { s.dig('Address', 'Name2') unless s.dig('Address', 'Name1') == s.dig('Address', 'Name2') })
          .>> t(:add_field, 'telephone', ->(s) { s.dig('Address', 'Mobile') || s.dig('Address', 'Phone') })
          .>> t(:add_field, 'fax_number', ->(s) { s.dig('Address', 'Fax') })
          .>> t(:add_field, 'email', ->(s) { s.dig('Address', 'EMail') })
          .>> t(:add_field, 'url', ->(s) { s.dig('Address', 'URL') })
          .>> t(:nest, 'contact_info', ['contact_name', 'telephone', 'fax_number', 'email', 'url'])
          .>> t(:add_field, 'name', ->(s) { s.dig('Address', 'Name1') })
          .>> t(:strip_all)
        end

        def self.event_schedule(data_hash)
          schedule_hash = {}
          dates = data_hash.dig('dates').map { |d| d&.in_time_zone }.sort
          schedule_hash[:dtstart] = dates.first
          duration = Time.zone.parse(data_hash.dig('Duration')) - Time.new(1900).in_time_zone
          schedule_hash[:dtend] = dates.last + duration
          options = { duration: duration.presence&.to_i }.compact

          schedule_object = IceCube::Schedule.new(schedule_hash[:dtstart].in_time_zone.presence || Time.zone.now, options) do |s|
            dates.each do |rd|
              s.add_recurrence_time(rd)
            end
          end
          schedule_hash[:duration] = duration if duration.present?
          schedule_hash.merge(schedule_object.to_hash)
        end

        def self.event_status(string)
          return [] if string.blank?
          bits = string.to_i
          bit_values = {
            0 => 'nur Veranstaltungskalender',
            1 => 'im Verkauf',
            2 => 'online',
            4 => 'vorübergehend gestoppt',
            8 => 'ausverkauft',
            16 => 'Event wurde abgesagt'
          }
          evaluate_bitmap(bits, bit_values, 'JetTicket - Eventstatus')
        end

        def self.event_flags(string)
          return [] if string.blank?
          bits = string.to_i
          bit_values = {
            1 => 'Vorstellungsvariante vorhanden',
            2 => 'Preisübersteuerung/Preistabelle vorhanden',
            4 => 'vorübergehend gestoppt',
            8 => 'Personalisierung vorhanden',
            16 => 'Packetverwendung erforderlich'
          }
          evaluate_bitmap(bits, bit_values, 'JetTicket - EventFlags')
        end

        def self.evaluate_bitmap(bits, bit_values, tree_label)
          return DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(tree_label, bit_values[0]) if bits.zero? && bit_values[0].present?
          bit_values
            .except(0)
            .keys
            .select { |v| (bits & v) == v }
            .map { |v| bit_values[v] }
            .map { |v| DataCycleCore::ClassificationAlias.classification_for_tree_with_name(tree_label, v) }
            .compact
        end

        def self.convert_country_code(jt_cc, external_source_id)
          return if jt_cc.blank?
          classification = DataCycleCore::Classification.find_by(external_source_id: external_source_id, external_key: "JetTicket - CountryCode - #{jt_cc}")
          class_alias = DataCycleCore::ClassificationAlias.for_tree('Ländercodes').find_by(description: classification.name)
          return if class_alias.blank?
          Array.wrap(class_alias.primary_classification.id)
        end
      end
    end
  end
end
