# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Audio
        class << self
          def duration(audio)
            meta_value(audio, ['audio_properties', 'length'])
          end

          def meta_value(audio_id, path)
            audio = DataCycleCore::Audio.find_by(id: audio_id)
            return nil if audio.blank? || path.blank?
            audio.exif_data.dig(*path)
          end
        end
      end
    end
  end
end
