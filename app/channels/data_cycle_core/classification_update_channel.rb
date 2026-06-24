# frozen_string_literal: true

module DataCycleCore
  class ClassificationUpdateChannel < ApplicationCable::Channel
    def subscribed
      reject && return unless current_user&.can?(:index, DataCycleCore::ClassificationTreeLabel)

      stream_from 'classification_update'
    end

    def unsubscribed
    end
  end
end
