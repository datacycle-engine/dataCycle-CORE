# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GipKeyFigures
      class Endpoint
        def initialize(host: nil, end_point: nil, key: nil, **options)
          @host = host
          @end_point = end_point
          @key = key
          @options = options
        end

        def get_key_figure(part_ids, key)
          part_ids = part_ids.reject(&:blank?)

          unless part_ids.present? && key.present?
            return OpenStruct.new(error: {
              path: 'frontend.validate.errors.no_data',
              substitutions: {
                data: 'GIP Kennzahlen'
              }
            })
          end

          @voo_id = voo_id(part_ids)

          if @voo_id.blank?
            return OpenStruct.new(error: {
              path: 'frontend.validate.errors.gip_no_plausible_route'
            })
          end

          data = Rails.cache.fetch(key_figure_cache_key, expires_in: 1.hour) do
            load_data(id: @voo_id)
          end

          if data.blank?
            return OpenStruct.new(error: {
              path: 'frontend.validate.errors.key_figure_not_found'
            })
          end

          key_figure = parse_key_figures(data, key)

          if key_figure.blank?
            return OpenStruct.new(error: {
              path: 'frontend.validate.errors.key_figure_not_found'
            })
          end

          key_figure
        end

        def voo_id(part_ids)
          result_id = nil

          sections = part_ids&.map { |id|
            content = DataCycleCore::Thing.find(id)
            if content.template_name == 'Gesamtroute'
              content.sections
            else
              content
            end
          }&.flatten&.uniq(&:id)

          # if only one section we use this for key figures
          if sections.length == 1
            @content_updated_at = sections&.first&.updated_at
            return sections&.first&.external_key&.sub(/^Event_/, '')
          end

          # only one 'Hauptroute in Richtung' is allowed, this is then taken for key figures, if there are more or none we return an error
          main_route_count = 0
          sections&.each do |section|
            next unless section&.template_name == 'Route' && section&.minortyperef&.first&.name == 'R: Hauptroute in Richtung'

            if main_route_count.positive?
              result_id = nil
              break
            else
              result_id = section&.external_key&.sub(/^Event_/, '')
            end

            @content_updated_at = section&.updated_at

            main_route_count += 1
          end

          result_id
        end

        def parse_key_figures(raw_data, key)
          return if raw_data.blank?
          return if raw_data.dig('features').blank?

          raw_data.dig('features').first[mapped_key(key)]
        end

        def load_data(id: nil)
          response = Faraday.new.get do |req|
            req.url(File.join(@host, @end_point, id))
            req.headers['Accept'] = 'application/json'
            req.params['usr'] = @key
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join(@host, @end_point, id)}", response) unless response.success?
          data = JSON.parse(response.body)

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{data['status']}, error loading data from #{File.join(@host, @end_point, id)}", response) unless data.try(:length)
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
          "gip_key_figure_#{@voo_id}_#{@content_updated_at.iso8601}"
        end
      end
    end
  end
end
