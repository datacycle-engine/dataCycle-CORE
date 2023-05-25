# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.identity(data)
          data
        end

        def self.hashify_data(data, key)
          return data unless data.key?(key)
          data[key] = data[key].map { |i|
            if i.keys.size > 2
              { i['t'] => i.except('t') }
            else
              { i['t'] => i['v'] }
            end
          }.inject(&:merge)
          data
        end

        def self.image_url(data, key, ids)
          id = ids.detect { |i| data.dig("#{data['type']}i", i, data['url_key']) }
          data[key] =
            if data['static_image'].present?
              format(data['static_image'], { image_size: id, external_id: data['rid'], design: data['design'] })
            else
              data.dig("#{data['type']}i", id, data['url_key'])
            end
          data
        end

        def self.add_urls(data)
          return data if data['urllist'].blank?
          urls = Array.wrap(data.dig('urllist', 'durl'))
          content_url = urls
            .detect { |i| i['t'] == 'MediaPlayer v4' }
            &.dig('v')
          data['content_url'] = content_url if content_url.present?
          url = urls
            .detect { |i| i['t'] == 'feratel.com' }
            &.dig('v')
          data['url'] = url if url.present?
          data
        end
      end
    end
  end
end
