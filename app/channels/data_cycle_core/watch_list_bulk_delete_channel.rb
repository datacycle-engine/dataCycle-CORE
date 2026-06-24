# frozen_string_literal: true

module DataCycleCore
  class WatchListBulkDeleteChannel < ApplicationCable::Channel
    def subscribed
      watch_list = DataCycleCore::WatchList.find_by(id: params[:watch_list_id])
      reject && return unless watch_list
      reject && return unless current_user&.can?(:bulk_delete, watch_list)

      stream_from "bulk_delete_#{params[:watch_list_id]}"
    end

    def unsubscribed
    end
  end
end
