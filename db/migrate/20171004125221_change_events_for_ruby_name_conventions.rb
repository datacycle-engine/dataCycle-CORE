# frozen_string_literal: true

class ChangeEventsForRubyNameConventions < ActiveRecord::Migration[5.0]
  def change
    rename_column :events, :startDate, :start_date
    rename_column :events, :endDate, :end_date

    rename_column :event_histories, :startDate, :start_date
    rename_column :event_histories, :endDate, :end_date
  end
end
