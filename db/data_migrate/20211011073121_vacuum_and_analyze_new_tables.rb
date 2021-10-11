# frozen_string_literal: true

class VacuumAndAnalyzeNewTables < ActiveRecord::Migration[5.2]
  def up
    return if Rails.env.test?

    DataCycleCore::RunTaskJob.perform_later('db:maintenance:vacuum_full')
  end

  def down
  end
end
