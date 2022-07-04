# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Video
        class << self
          def thumbnail_url(virtual_parameters:, content:, **_args)
            virtual_parameters.each do |virtual_key|
              val = content.try(virtual_key.to_sym)
              return val if val.present?
            end
            video = content.asset
            thumb_url = nil
            if DataCycleCore.experimental_features.dig('active_storage', 'enabled') && video&.file&.attached?
              begin
                ActiveStorage::Current.set(host: Rails.application.config.asset_host) do
                  thumb_url = video.file.preview(resize_to_limit: [300, 300]).processed.url
                end
              rescue ActiveStorage::FileNotFoundError
                # add some logging
                return nil
              end
            else
              thumb_url = video&.file&.thumb_preview&.url
            end
            thumb_url
          end
        end
      end
    end
  end
end
