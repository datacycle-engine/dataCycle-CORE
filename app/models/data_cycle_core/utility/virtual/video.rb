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
            if video&.file&.attached?
              begin
                DataCycleCore::ActiveStorageService.with_current_options do
                  thumb_url = video.file.preview(resize_to_limit: [300, 300]).processed.url
                end
              rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError
                # @todo: add some logging
                return nil
              end
            end
            thumb_url
          end
        end
      end
    end
  end
end
