# frozen_string_literal: true

module DataCycleCore
  class ClassificationUpdateChannel < ApplicationCable::Channel
    def subscribed
      stream_from 'classification_update'
    end

    def unsubscribed
    end
  end
end
