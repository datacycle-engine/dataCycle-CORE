# frozen_string_literal: true

module DataCycleCore
  class BulkCreateChannel < ApplicationCable::Channel
    def subscribed
      reject && return if current_user.blank?
      stream_from "bulk_create_#{params[:overlay_id]}_#{current_user.id}"
    end

    def unsubscribed
    end
  end
end
