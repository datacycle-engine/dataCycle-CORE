# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      module TransformationsGlobal
        ODTA_TYPE = {
          'TouristAttraction' => 'odta:PointOfInterest',
          'dcls:Tour' => 'odta:Trail',
          'Rating' => 'aggregateRating',
          'https://schema.org/ViewAction' => 'Action'
        }.freeze

        COMPLIES = {
          'TouristAttraction' => 'https://semantify.it/ds/sloejGAwT', # 'POI'
          'Event' => 'https://semantify.it/ds/mhpmBCJJt',
          'FoodEstablishment' => 'https://semantify.it/ds/SyCG2WVzkz',
          'LodgingBusiness' => 'https://semantify.it/ds/Sypf3bVG1z', # Unterkunft
          'Person' => 'https://semantify.it/ds/iB4eyYN5K', # https://semantify.it/ds/luBQ_A5Y- (copyright/license Author)
          'odta:Trail' => 'https://semantify.it/ds/nBTyKDsKX', # Tour
          'GeoShape' => 'https://semantify.it/ds/puYUsMkUP',
          'GeoCoordinates' => 'https://semantify.it/ds/2NErTNGpd',
          'aggregateRating' => 'https://semantify.it/ds/d6ZpC7eZo',
          'PostalAddress' => 'https://semantify.it/ds/NP8df6sKy',
          'OpeningHoursSpecification' => 'https://semantify.it/ds/rpOsHCyrE',
          'PropertyValue' => 'https://semantify.it/ds/evJvhycX1',
          'ImageObject' => 'https://semantify.it/ds/ufjX_Cc5w',
          'Organization' => 'https://semantify.it/ds/Wf-IXZvIo',
          'Action' => 'https://semantify.it/ds/mhpmBCJJt#ChFfq'
        }.freeze

        WHITELIST_NAMESPACED_DATA = ['odta:wayPoint'].freeze

        TRANSFORMATION_TYPES = {
          'PropertyValue' => :to_property_value,
          'dcls:Person' => :to_person,
          'dcls:Organization' => :to_organization,
          'dcls:Bild' => :to_image,
          'dcls:POI' => :to_poi,
          'dcls:Unterkunft' => :to_lodging_business,
          'dcls:Gastronomischer Betrieb' => :to_food_establishment,
          'dcls:Tour' => :to_tour,
          'dcls:Event' => :to_event
        }.freeze

        def self.transform_types(data)
          case data
          in Hash
            transformed_data = nil
            transformation = TRANSFORMATION_TYPES
              .values_at(*Array.wrap(data['@type']))
              .compact
              .last
            transformed_data = DataCycleCore::Export::Onlim::Transformations.send(transformation).call(data) if transformation.present?
            (transformed_data || data).map { |k, v|
              { k => transform_types(v) }
            }&.reduce(&:merge)
          in Array
            data.map { |i| transform_types(i) }
          else
            data
          end
        end

        def self.remove_namespaced_data(data)
          case data
          in Hash
            data
              .reject { |k, _v| !k.in?(WHITELIST_NAMESPACED_DATA) && k.count(':').positive? }
              &.transform_values { |v| remove_namespaced_data(v).presence }
              &.compact
          in Array
            data.map { |i| remove_namespaced_data(i) }
          else
            data
          end
        end

        def self.context_to_onlim(data)
          return data unless data.key?('@context')
          context = data['@context']
          context = Array.wrap(
            context[1].merge(
              {
                '@vocab' => 'https://schema.org/',
                'rdfs' => 'http://www.w3.org/2000/01/rdf-schema#',
                'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
                'xsd' => 'http://www.w3.org/2001/XMLSchema#',
                'odta' => 'https://odta.io/voc/',
                'ds' => 'https://vocab.sti2.at/ds/'
              }
            ).reject { |k, _| k.in?('dcls') }
          )
          data['@context'] = context

          data
        end

        def self.remove_thing_stubs(data)
          case data
          in Hash
            if data.keys == ['@id'] # for 'ds:compliesWith'
              data
            elsif (data.keys - ['@id', '@type', 'ds:compliesWith']).present?
              data
                .transform_values { |v| remove_thing_stubs(v).presence }
                &.compact
            end
          in Array
            data
              .map { |i| remove_thing_stubs(i) }
              &.compact
              &.presence
          else
            data
          end
        end

        def self.remove_existing_object_data(data, existing_ids)
          case data
          in Hash
            if data['@id'].in?(existing_ids)
              { '@id' => data['@id'] }
            else
              data
                .transform_values { |v| remove_existing_object_data(v, existing_ids) }
                &.compact
            end
          in Array
            data.map { |i| remove_existing_object_data(i, existing_ids) }
          else
            data
          end
        end

        def self.type_to_onlim(data)
          case data
          in Hash
            data
              .map { |k, v| k == '@type' ? { k => update_type(v) } : { k => type_to_onlim(v) } }
              &.reduce(&:merge)
          in Array
            data.map { |i| type_to_onlim(i) }
          else
            data
          end
        end

        def self.update_type(type)
          types = Array
            .wrap(type)
            .map { |i| [i, ODTA_TYPE[i]].compact }
            .flatten
            .reject { |i| i.start_with?('dcls:') }
            .reject { |i| i.start_with?('https://') }
            .uniq
          if types.size == 1
            types.first
          elsif types.include?('Organization')
            types.reject { |i| i == 'Organization' } # remove Organization (conflicts with white/blacklist)
          else
            types
          end
        end

        def self.add_complies_with(data)
          return data unless data.is_a?(Hash) || data.is_a?(Array)

          case data
          in Hash
            if data.key?('@type') && Array.wrap(data['@type']).any? { |i| i.in?(COMPLIES.keys) }
              complies_with = Array.wrap(data['@type']).detect { |i| COMPLIES[i].present? }.then { |i| COMPLIES[i] }
              data.merge({ 'ds:compliesWith' => { '@id' => complies_with } })
            else
              data
            end.transform_values { |v| add_complies_with(v) }
          in Array
            data.map { |i| add_complies_with(i) }
          else
            data
          end
        end

        def self.add_main_content_license(data)
          return data unless data.key?('@graph')
          content_data = data['@graph'].first

          thing = DataCycleCore::Thing.find(content_data.dig('@id'))
          sd_license = DataCycleCore::ClassificationAlias.for_tree('Lizenzen').with_name(thing.classification_aliases.reorder(nil).pluck(:name)).pluck(:uri)
          content_data['sdLicense'] = sd_license.first if sd_license.size.positive?

          publisher_data =
            case thing.template_name
            in 'POI'
              content_data['copyrightHolder']&.first.presence || content_data['author']&.first.presence
            in 'Tour' | 'Gastronomischer Betrieb' | 'Unterkunft'
              content_data['sdPublisher']&.first.presence || content_data['copyrightHolder']&.first.presence
            else
              nil
            end

          if publisher_data.present?
            content_data['sdPublisher'] =
              Array.wrap(
                DataCycleCore::Export::Onlim::Transformations.default_transformations.call(publisher_data)
              )
          end

          data['@graph'] = Array.wrap(content_data)
          data
        end

        def self.apply_blacklist(data, list)
          return data if data.blank? || list.blank?
          raise "Function parameter <list> has to be a Hash { type => Array(attributes) } not #{list.class}." unless list.is_a?(Hash)
          list.each_key { |type| data = apply_list_type(data, type, list[type], :reject_attributes) }
          data
        end

        def self.apply_whitelist(data, list)
          return data if data.blank? || list.blank?
          raise "Function parameter <list> has to be a Hash { type => Array(attributes) } not #{list.class}." unless list.is_a?(Hash)
          list.each_key { |type| data = apply_list_type(data, type, list[type], :select_attributes) }
          data
        end

        def self.apply_list_type(data, type, list, hash_method)
          return data if data.blank? || list.blank?
          raise 'Function parameter <type> can not be empty.' if type.blank?

          case data
          in Hash
            if data.key?('@type') && Array.wrap(data['@type']).any?(type)
              send(hash_method, data, list)
            else
              data
            end.transform_values { |v| apply_list_type(v, type, list, hash_method) }
          in Array
            data.map { |i| apply_list_type(i, type, list, hash_method) }
          else
            data
          end
        end

        def self.reject_attributes(data, list)
          return data if data.blank? || list.blank?
          raise "Function parameter <list> has to be an Array not #{list.class}." unless list.is_a?(Array)
          list.each do |path|
            data = reject_attribute(data, path)
          end
          data
        end

        def self.reject_attribute(data, path)
          return data if path.blank?
          path = Array.wrap(path)
          key = path[0]
          leaf = path.size <= 1
          case data
          in Hash
            data[key] = reject_attribute(data[key], path[1..-1]) if data.key?(key)
            data.reject! { |k, _| k == key } if leaf
            data.compact.presence
          in Array
            data.map { |i| reject_attribute(i, path) }.compact.presence
          else
            data
          end
        end

        def self.select_attributes(data, list)
          return data if list.blank? || data.blank?
          list.map! { |i| Array.wrap(i) }
          keys = list.map(&:first).uniq
          case data
          in Hash
            data
              .select { |k, _| k.in?(keys) || k.starts_with?('@') }
              .map { |k, v|
                next_level = list.select { |i| i[0] == k }.map { |i| i[1..-1].presence }.compact
                { k => select_attributes(v, next_level) }
              }.reduce(&:merge)
              &.compact
              &.presence
          in Array
            data.map { |i| select_attributes(i, list) }&.compact&.presence
          else
            nil
          end
        end
      end
    end
  end
end
