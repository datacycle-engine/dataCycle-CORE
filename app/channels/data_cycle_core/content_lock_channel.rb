# frozen_string_literal: true

module DataCycleCore
  class ContentLockChannel < ApplicationCable::Channel
    def subscribed
      reject && return unless DataCycleCore::Feature::ContentLock.enabled?

      content = DataCycleCore::Thing.find_by(id: params[:content_id])
      reject && return unless content
      reject && return unless current_user&.can?(:show, content)

      stream_from "content_lock_#{params[:content_id]}"
    end

    def unsubscribed
    end
  end
end
