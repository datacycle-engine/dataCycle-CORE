# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GIPKeyFigures
      class Endpoint
        def initialize(host: nil, end_point: nil, key: nil, **options)
          @host = host
          @end_point = end_point
          @key = key
          @options = options
        end

        def get_key_figure(part_ids, key)
          @part_ids = part_ids

          unless part_ids.present? && key.present? && voo_id.present?
            return OpenStruct.new(error: {
              path: 'validation.warnings.no_data',
              substitutions: {
                data: 'GeoKeyFeature'
              }
            })
          end

          data = Rails.cache.fetch(key_figure_cache_key, expires_in: 1.hour) do
            load_data(id: voo_id)
          end

          if data.blank?
            OpenStruct.new(error: {
              path: 'validation.warnings.key_figure_not_found'
            })
          end

          key_figure = parse_key_figures(data, key)

          if key_figure.blank?
            return OpenStruct.new(error: {
              path: 'validation.warnings.key_figure_not_found'
            })
          end

          key_figure
        end

        def voo_id
          @voo_id ||= find_voo_id
        end

        def find_voo_id
          result_id = nil

          @part_ids&.map { |id|
            content = DataCycleCore::Thing.find(id)
            if content.template_name == 'Gesamtroute'
              content.sections
            else
              content
            end
          }&.flatten&.uniq(&:id)&.each do |section|
            next unless section.template_name == 'Route' && section.minortyperef.first.name == 'R: Hauptroute in Richtung'
            @content_updated_at = section.updated_at
            result_id = section.external_key.sub(/^Event_/, '')
          end
          result_id
        end

        def parse_key_figures(raw_data, key)
          return if raw_data.blank?
          raw_data.dig('features').first[mapped_key(key)]
        end

        def load_data(id: nil)
          response = Faraday.new.get do |req|
            req.url(File.join(@host, @end_point, id))
            req.headers['Accept'] = 'application/json'
            req.params['usr'] = @key
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point + id + 'geocode/json'}", response) unless response.success?
          data = JSON.parse(response.body)

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{data['status']}, error loading data from #{@host + @end_point + id + 'geocode/json'}", response) unless data.try(:length)
          data
        end

        def mapped_key(key)
          case key
          when 'length'
            'laenge'
          when 'duration'
            'fahrzeit'
          when 'ascent'
            'hoehebergauf'
          when 'descent'
            'hoehebergab'
          else
            ''
          end
        end

        def key_figure_cache_key
          "gip_key_figure_#{voo_id}_#{@content_updated_at.iso8601}"
        end
      end
    end
  end
end
