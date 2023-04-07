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

        def self.identity(data)
          # binding.pry
          data
        end

        def self.transform_action(data)
          case data
          in Hash
            data
              .map { |k, v|
                if k == 'potentialAction'
                  v_new = v.map do |adata|
                    adata
                      .slice('name', 'url', '@type', '@id')
                      .map { |attk, attv|
                        if attk.in?(['@type', '@id'])
                          { attk => attv }
                        else
                          new_attv = Array.wrap(attv).detect { |i| i['@language'] == 'de' }&.dig('@value')
                          { attk => new_attv || Array.wrap(attv).first.dig('@value') }
                        end
                      }.reduce(&:merge)
                  end
                  { k => v_new }
                else
                  { k => transform_action(v) }
                end
              }&.reduce(&:merge)
          in Array
            data.map { |i| transform_action(i) }
          else
            data
          end
        end

        def self.transform_time(data, keys)
          case data
          in Hash
            data
              .map { |k, v| k.in?(keys) && v.present? && v.split(':').size == 2 ? { k => v + ':00' } : { k => transform_time(v, keys) } }
              &.reduce(&:merge)
          in Array
            data.map { |i| transform_time(i, keys) }
          else
            data
          end
        end

        def self.transform_duration(data)
          case data
          in Hash
            data
              .map { |k, v|
                if k == 'duration' && v.present?
                  { k => { '@id' => generate_uuid(data['@id'], 'duration'), '@type' => 'Duration', 'name' => v } }
                else
                  { k => transform_duration(v) }
                end
              }&.reduce(&:merge)
          in Array
            data.map { |i| transform_duration(i) }
          else
            data
          end
        end

        def self.transform_copyright_notice(data)
          add_node(data) do |gdata|
            if gdata['copyrightNotice'].present?
              gdata['copyrightNotice'] = {
                '@value' => gdata['copyrightNotice'],
                '@type' => 'http://www.w3.org/2001/XMLSchema#string'
              }
            end
          end
        end

        def self.add_contact_information(data, attributes = [])
          add_node(data) do |gdata|
            if gdata.dig('address').present?
              contact_info = gdata
                .dig('address')
                .select { |k, _v| k.in?(attributes) }
                .map { |k, v|
                  new_v = Array.wrap(v).detect { |i| i['@language'] == 'de' }&.dig('@value')
                  { k => new_v || Array.wrap(v).first.dig('@value') }
                }.reduce(&:merge)
              gdata.merge!(contact_info) if contact_info.present?
            end
          end
        end

        def self.add_place_description(data)
          external_names = [
            'description_long', # imx_platform
            'text', # OutdoorActive & long text legacy
            'book', # Bierfinder
            'details', # destination.one
            'beschreibung', 'teaser', # Wintop
            'longText', 'longDescription', # dataHub ATS
            'description', # several
            'shortDescription', # Venus
            'abstract', # mein.toubiz
            'intro' # TIMM4
          ]

          add_description(data, external_names, true)
        end

        def self.add_tour_description(data)
          external_names = [
            'description_long', # imx_platform
            'text', # OutdoorActive & long text legacy
            'details', # destination.one
            'longText', 'longDescription', # dataHub ATS
            'description', # several
            'abstract', # mein.toubiz
            'intro', # TIMM4
            'shortDescription' # Venus
          ]

          add_description(data, external_names)
        end

        def self.add_food_establishment_description(data)
          external_names = [
            'description_long', # imx_platform
            'book', # Bierfinder
            'details', # destination_one
            'beschreibung', 'teaser', # Wintop
            'description', # several
            'abstract', # mein.toubiz
            'intro', # TIMM4
            'shortDescription' # Venus
          ]

          add_description(data, external_names)
        end

        def self.add_lodging_business_description(data)
          external_names = [
            'text', # OutdoorActive & long text legacy
            'description_long', # imx.platform
            'details', # destination_one
            'ServiceProviderDescription', # Feratel
            'description', # mein.touzbiz &more
            'shortDescription' # Venus
          ]

          add_description(data, external_names)
        end

        def self.add_event_description(data)
          external_names = [
            'details', # destination_one
            'longText', 'longDescription', # dataHub ATS
            'description', # mein.touzbiz &more
            'abstract', # mein.toubiz
            'intro', # TIMM4
            'teaser', # destination_one
            'shortDescription' # Venus
          ]

          add_description(data, external_names)
        end

        def self.add_description(data, external_names, additional_property = false)
          add_node(data) do |gdata|
            desc = gdata
              .dig('description')
              .presence
              &.map { |i| { i['@language'] => i['@value'] } }
              &.inject(&:merge) || {}

            desc_long = nil
            if additional_property
              desc_long = gdata
                .dig('additionalProperty')
                &.select { |i| i['identifier'] == 'text' }
                &.first
                &.send(:[], 'value')
                &.map { |i| { i['@language'] => i['@value'] } }
                &.inject(&:merge)
            end
            desc_long ||= find_description_long(external_names, gdata.dig('dc:additionalInformation'))

            desc = desc.merge(desc_long) if desc_long.present?
            gdata['description'] = desc.map { |k, v| { '@language' => k, '@value' => v } }
          end
        end

        def self.find_description_long(names, information)
          return if information.blank?
          return if names.blank?
          desc_long = nil

          ids = DataCycleCore::ClassificationAlias
            .for_tree('Externe Informationstypen')
            .with_name(names)
            .pluck(:id, :name)
            .sort_by { |_, name| names.index(name) }
            .map { |id, _| id }

          ids.each do |classification|
            desc_long = information
              .select { |i| i['dc:classification']&.first&.send(:[], '@id') == classification }
              &.map { |i| i['description'].map { |d| { d['@language'] => d['@value'] } }.compact_blank }
              &.flatten
              &.compact_blank
              &.inject(&:merge)
            break if desc_long.present?
          end
          desc_long
        end

        def self.add_action_as_url(data)
          add_node(data) do |gdata|
            if gdata.dig('potentialAction').present? && gdata.dig('url').blank?
              url = gdata
                .dig('potentialAction')
                .detect { |i| i['name'].detect { |j| j['@value'] == 'URL' }.present? }
                .dig('url')
                .first
                .dig('@value')

              gdata['url'] = url if url.present?
            end
          end
        end

        def self.add_keywords(data)
          add_node(data) do |gdata|
            if gdata.dig('dc:classification')&.compact_blank.present?
              gdata['keywords'] = gdata
                .dig('dc:classification')
                &.map { |i|
                  i['skos:prefLabel'].map do |item|
                    if item.is_a?(::Hash)
                      item.tap do |value_hash|
                        value_hash['@value'] = value_hash['@value'].to_s
                      end
                    else
                      item
                    end
                  end
                }&.flatten
                &.uniq
            end
          end
        end

        def self.transform_content_size(data)
          add_node(data) do |gdata|
            gdata['contentSize'] = gdata['contentSize'].to_i.to_s if gdata['contentSize'].present?
          end
        end

        def self.transform_numbers(data)
          add_node(data) do |gdata|
            gdata['value'] = gdata['value'].first['@value'] if gdata['value'].present? && gdata['value'].first['@value'].is_a?(::Numeric)
          end
        end

        def self.rename_graph_keys(data, key_map)
          add_node(data) do |gdata|
            key_map.each_key do |k|
              next if gdata[k].blank?
              gdata[key_map[k]] = gdata[k]
              gdata.delete(k)
            end
          end
        end

        def self.add_node(data, &block)
          if data.key?('@graph')
            graphdata = data['@graph'].first
            graphdata.tap(&block)
            data['@graph'] = [graphdata]
          else
            data.tap(&block)
          end
          data
        end
      end
    end
  end
end
