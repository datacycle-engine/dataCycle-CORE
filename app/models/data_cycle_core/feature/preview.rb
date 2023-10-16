# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Preview < Base
      class << self
        def available_widgets(endpoint, ui_locale = :de)
          configuration.dig(:widgets)&.compact_blank&.transform_values do |url|
            if url.is_a?(::Hash)
              send("url_to_v#{url[:version] || 2}", url[:url], endpoint, ui_locale)
            else
              url_to_v2(url, endpoint, ui_locale)
            end
          end
        end

        def url_to_v2(url, endpoint, _ui_locale)
          "#{url}?data_cycle_widget[endpoint]=#{endpoint}"
        end

        def url_to_v3(url, endpoint, ui_locale)
          "#{url}?api-endpoint=#{endpoint}&locale=#{ui_locale}"
        end
      end
    end
  end
end
