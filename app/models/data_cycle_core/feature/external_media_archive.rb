# frozen_string_literal: true

module DataCycleCore
  module Feature
    class ExternalMediaArchive < Base
      class << self
        def get_template_name(asset_type)
          if asset_type == 'video'
            [configuration.dig('template_mapping')&.key('image')&.camelize, configuration.dig('template_mapping')&.key('video')&.camelize]
          else
            configuration.dig('template_mapping')&.key(asset_type)&.camelize
          end
        end
      end
    end
  end
end
