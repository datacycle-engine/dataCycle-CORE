# frozen_string_literal: true

module DataCycleCore
  class BulkCreateChannel < ApplicationCable::Channel
    def subscribed
      stream_from "bulk_create_#{current_user.id}"
    end

    def unsubscribed
    end
  end
end
