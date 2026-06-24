# frozen_string_literal: true

class AddGrafanaDoorkeeperApplication < ActiveRecord::Migration[8.0]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    return unless ENV['GRAFANA_OAUTH_CLIENT_ID'].present? && ENV['GRAFANA_OAUTH_CLIENT_SECRET'].present?

    DataCycleCore::RunTaskJob.perform_later('dc:oauth:clients:upsert_grafana')
  end

  def down
  end
end
