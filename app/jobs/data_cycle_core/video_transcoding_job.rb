# frozen_string_literal: true

module DataCycleCore
  class VideoTranscodingJob < UniqueApplicationJob
    queue_as :default
    queue_with_priority 12
    limits_concurrency key: ->(*args) { "#{args[0]}/#{args[1]}" }

    def perform(content_id, computed_property_name)
      content = DataCycleCore::Thing.find(content_id)
      computed_definition = content.properties_for(computed_property_name)
      variant = computed_definition.dig('compute', 'transformation', 'version')
      processed_video_url = DataCycleCore::Feature::VideoTranscoding.process_video(content:, variant:)
      content.set_data_hash(data_hash: { computed_property_name => processed_video_url }, update_computed: false)
    end
  end
end
