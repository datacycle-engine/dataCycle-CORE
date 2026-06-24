# frozen_string_literal: true

module DataCycleCore
  class BulkCreateChannel < ApplicationCable::Channel
    def subscribed
      reject && return unless current_user&.can?(:create, DataCycleCore::Asset)

      stream_from "bulk_create_#{params[:overlay_id]}_#{current_user.id}"
    end

    def unsubscribed
    end
  end
end
