# frozen_string_literal: true

module DataCycleCore
  class WatchListBulkDeleteChannel < ApplicationCable::Channel
    def subscribed
      stream_from "bulk_delete_#{params[:watch_list_id]}"
    end

    def unsubscribed
    end
  end
end
