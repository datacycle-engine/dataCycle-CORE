# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Audio
        class << self
          def duration(**args)
            meta_value(args.dig(:computed_parameters)&.first, ['audio_properties', 'length'])&.to_f || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def content_url(computed_parameters:, **_args)
            audio = DataCycleCore::Audio.find_by(id: computed_parameters.values.first)
            if DataCycleCore.experimental_features.dig('active_storage', 'enabled') && audio&.file&.attached?
              Rails.application.routes.url_helpers.rails_storage_proxy_url(audio.file, host: Rails.application.config.asset_host)
            else
              audio&.try(:file)&.try(:url)
            end
          end

          def meta_value(audio_id, path)
            audio = DataCycleCore::Audio.find_by(id: audio_id)
            return nil if audio.blank? || path.blank?
            audio&.metadata&.dig(*path)
          end
        end
      end
    end
  end
end
