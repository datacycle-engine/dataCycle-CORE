# frozen_string_literal: true

module DataCycleCore
  class VideoTranscodingJob < UniqueApplicationJob
    PRIORITY = 12

    REFERENCE_TYPE = 'video_transcoding'

    queue_as :default

    def priority
      PRIORITY
    end

    def delayed_reference_id
      "#{arguments[0]}_#{arguments[1]}"
    end

    def delayed_reference_type
      REFERENCE_TYPE
    end

    def perform(content_id, computed_property_name)
      content = DataCycleCore::Thing.find(content_id)
      computed_definition = content.properties_for(computed_property_name)
      variant = computed_definition.dig('compute', 'transformation', 'version')
      processed_video_url = DataCycleCore::Feature::VideoTranscoding.process_video(content: content, variant: variant)
      content.set_data_hash(data_hash: { computed_property_name => processed_video_url }, partial_update: true, update_computed: false)
    end
  end
end
