# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions
        import DataCycleCore::Export::Onlim::TransformationsGlobal

        extend DataCycleCore::ContentHelper

        def self.transform_opening_hours_specifications(data)
          add_node(data) do |gdata|
            return data if gdata.dig('openingHoursSpecification').blank?
            gdata['openingHoursSpecification'] = gdata
              .dig('openingHoursSpecification')
              .map do |s|
                s['opens'] += ':00' if s.dig('opens').present?
                s['closes'] += ':00' if s.dig('closes').present?
                s
              end
          end
        end

        def self.transform_schedule(data)
          return data if data.dig('@graph', 0, 'eventSchedule').blank?
          schedules = data.dig('@graph', 0, 'eventSchedule')
          new_schedules = schedules.map do |i|
            i['startTime'] += ':00' if i['startTime'].present? && i['startTime'].split(':').size == 2
            i['endTime'] += ':00' if i['endTime'].present? && i['endTime'].split(':').size == 2
            i['duration'] = { '@id' => generate_uuid(i['@id'], 'duration'), '@type' => 'Duration', 'name' => i['duration'] } if i['duration'].present?
            i
          end
          data['@graph'][0]['eventSchedule'] = new_schedules
          data
        end

        def self.add_contact_information(data, content)
          return data if !content.respond_to?(:contact_info) || content.contact_info.blank?
          add_node(data) do |gdata|
            contact_info = content
              .contact_info
              .to_h
              .except('contact_name', 'email')
              .transform_keys { |k| k.camelize(:lower) }
            gdata.merge!(contact_info) if contact_info.present?
          end
        end

        def self.add_url(data, content)
          return data if !content.respond_to?(:contact_info) || content.contact_info.url.blank?
          add_node(data) do |gdata|
            gdata['url'] = content.contact_info.url
          end
        end

        def self.add_description(data, content)
          return data if !content.respond_to?(:description) || content.description.blank?
          add_node(data) do |gdata|
            gdata['description'] = add_lnode(content) { content.description }
          end
        end

        def self.add_keywords(data, content)
          add_node(data) do |gdata|
            gdata['keywords'] = add_lnode_array(content) { content.classification_aliases.pluck(:name).compact }
          end
        end

        def self.add_identifier(data, content)
          add_node(data) do |gdata|
            gdata['identifier'] = content.id
          end
        end

        def self.add_node(data, &block)
          graphdata = data['@graph'].first
          graphdata.tap(&block)
          data['@graph'] = [graphdata]
          data
        end

        def self.add_lnode(content)
          locales = content.available_locales.map(&:to_s)
          locales.map { |l|
            I18n.with_locale(l) do
              value = yield
              next if value.blank?
              {
                '@value' => value,
                '@language' => l
              }
            end
          }.compact_blank
        end

        def self.add_lnode_array(content)
          locales = content.available_locales.map(&:to_s)
          locales.map { |l|
            I18n.with_locale(l) do
              values = yield
              next if values.blank?
              values.map do |value|
                {
                  '@value' => value,
                  '@language' => l
                }
              end
            end
          }.compact_blank
          .flatten
        end
      end
    end
  end
end
