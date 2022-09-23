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

        ODTA_TYPE = {
          'TouristAttraction' => 'odta:PointOfInterest',
          'Tour' => 'Trail'
        }.freeze

        COMPLIES = {
          'TouristAttraction' => 'https://semantify.it/ds/sloejGAwT', # 'POI'
          'Event' => 'https://semantify.it/ds/mhpmBCJJt',
          'FoodEstablishment' => 'https://semantify.it/ds/SyCG2WVzkz',
          'LodgingBusiness' => 'https://semantify.it/ds/Sypf3bVG1z', # Unterkunft
          'Person' => 'https://semantify.it/ds/iB4eyYN5K',
          'Tour' => 'https://semantify.it/ds/nBTyKDsKX',
          'GeoCoordinates' => 'https://semantify.it/ds/2NErTNGpd',
          'PostalAddress' => 'https://semantify.it/ds/NP8df6sKy',
          'OpeningHoursSpecification' => 'https://semantify.it/ds/rpOsHCyrE',
          'PropertyValue' => 'https://semantify.it/ds/evJvhycX1'
        }.freeze

        def self.remove_namespaced_data(data)
          case data
          in Hash
            data
              .reject { |k, _v| k.count(':').positive? }
              &.transform_values { |v| remove_namespaced_data(v).presence }
              &.compact
          in Array
            data.map { |i| remove_namespaced_data(i) }
          else
            data
          end
        end

        def self.context_to_onlim(data)
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
            if data.keys.sort != ['@id', '@type']
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
          if types.size == 1
            types.first
          elsif types.include?('Organization')
            types.reject { |i| i == 'Organization' } # remove Organization (conflicts with whiet/blacklist)
          else
            types
          end
        end

        def self.add_complies_with(data)
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
