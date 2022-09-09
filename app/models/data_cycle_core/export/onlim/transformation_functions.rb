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
          'TouristAttraction' => 'odta:PointOfInterest'
        }.freeze

        COMPLIES = {
          'POI' => 'https://semantify.it/ds/sloejGAwT',
          'Event' => 'https://semantify.it/ds/mhpmBCJJt'
        }.freeze

        def self.remove_namespaced_data(data)
          case data
          in Hash
            data
              .reject { |k, _v| k.count(':').positive? }
              &.map { |k, v| { k => remove_namespaced_data(v) } }
              &.reduce(&:merge)
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
                '@vocab' => 'https://schema.org',
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
                .map { |k, v| { k => remove_thing_stubs(v) } }
                &.reduce(&:merge)
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

        def self.add_complies_with(data)
          case data
          in Hash
            if data.key?('@type') && Array.wrap(data['@type']).any? { |i| i.in?(COMPLIES.keys) }
              complies_with = Array.wrap(data['@type']).detect { |i| COMPLIES[i].present? }.then { |i| COMPLIES[i] }
              data.merge({ 'ds:compliesWith' => { '@id' => complies_with } })
            else
              data
            end.map { |k, v| { k => add_complies_with(v) } }&.reduce(&:merge)
          in Array
            data.map { |i| add_complies_with(i) }
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
          types.size == 1 ? types.first : types
        end

        def self.apply_full_blacklist(data, blacklist)
          return data if data.blank? || blacklist.blank?
          raise "Function parameter <blacklist> has to be a Hash { type => Array(attributes) } not #{blacklist.class}." unless blacklist.is_a?(Hash)
          types = blacklist.keys
          types.each { |type| data = apply_blacklist(data, type, blacklist[type]) }
          data
        end

        def self.apply_blacklist(data, type, list)
          return data if data.blank?
          raise 'Function parameter <type> can not be empty.' if type.blank?

          case data
          in Hash
            if data.key?('@type') && Array.wrap(data['@type']).any?(type)
              reject_attributes(data, list)
            else
              data
            end.map { |k, v| { k => apply_blacklist(v, type, list) } }&.reduce(&:merge)
          in Array
            data.map { |i| apply_blacklist(i, type, list) }
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
      end
    end
  end
end
