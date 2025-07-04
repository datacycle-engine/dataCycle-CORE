# frozen_string_literal: true

module DataCycleCore
  class AdminDashboardJobsChannel < ApplicationCable::Channel
    def subscribed
      stream_from 'admin_dashboard_jobs'
    end
  end
end
