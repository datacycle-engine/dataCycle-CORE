# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Audio
        class << self
          def duration(audio)
            meta_value(audio, ['audio_properties', 'length'])&.to_f
          end

          def meta_value(audio_id, path)
            audio = DataCycleCore::Audio.find_by(id: audio_id)
            return nil if audio.blank? || path.blank?
            audio.metadata.dig(*path)
          end
        end
      end
    end
  end
end