# frozen_string_literal: true

module DataCycleCore
  class WatchListBulkUpdateChannel < ApplicationCable::Channel
    def subscribed
      reject && return if current_user.blank?
      stream_from "bulk_update_#{params[:watch_list_id]}_#{current_user.id}"
    end

    def unsubscribed
    end
  end
end
