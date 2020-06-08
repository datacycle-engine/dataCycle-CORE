# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Audio
        class << self
          def duration(**args)
            meta_value(args.dig(:computed_parameters)&.first, ['audio_properties', 'length'])&.to_f || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
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
