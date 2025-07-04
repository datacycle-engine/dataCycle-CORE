# frozen_string_literal: true

module DataCycleCore
  class AdminDashboardImportChannel < ApplicationCable::Channel
    def subscribed
      stream_from 'admin_dashboard_import'
    end
  end
end
