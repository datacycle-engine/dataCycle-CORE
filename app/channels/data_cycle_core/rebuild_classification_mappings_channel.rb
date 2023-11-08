# frozen_string_literal: true

module DataCycleCore
  class RebuildClassificationMappingsChannel < ApplicationCable::Channel
    def subscribed
      stream_from 'rebuild_classification_mappings'
    end

    def unsubscribed
    end
  end
end
