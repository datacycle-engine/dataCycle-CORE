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

        TRANSFORMATION_TYPES = {
          'Organization' => :to_organization,
          'Person' => :to_person,
          'ImageObject' => :to_image,
          'TouristAttraction' => :to_poi,
          'LodgingBusiness' => :to_lodging_business,
          'FoodEstablishment' => :to_lodging_business,
          'odta:Trail' => :to_tour,
          'Event' => :to_event
        }.freeze

        # def self.debug(data)
        #   binding.pry
        #   data
        # end

        def self.identity(data)
          data
        end

        def self.transform_thing_to_onlim(data)
          transform_onlim_type(data)
        end

        def self.transform_onlim_type(data)
          case data
          in Hash
            transformed_data = nil
            transformation = Array.wrap(data['@type'])
              .select { |i| i.in?(TRANSFORMATION_TYPES.keys) }
              .map { |i| TRANSFORMATION_TYPES[i] }
              .first
            transformed_data = DataCycleCore::Export::Onlim::Transformations.send(transformation).call(data) if transformation.present?
            (transformed_data || data).map { |k, v|
              { k => transform_onlim_type(v) }
            }&.reduce(&:merge)
          in Array
            data.map { |i| transform_onlim_type(i) }
          else
            data
          end
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

        def self.add_keywords(data)
          add_node(data) do |gdata|
            if gdata.dig('dc:classification').present?
              gdata['keywords'] = gdata
                .dig('dc:classification')
                .map { |i| i['skos:prefLabel'] }
                .flatten
                .uniq
            end
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
