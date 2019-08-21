# frozen_string_literal: true

module DataCycleCore
  class ContentLockChannel < ApplicationCable::Channel
    def subscribed
      stream_from "content_lock_#{params[:content_id]}"
    end

    def unsubscribed
    end
  end
end
