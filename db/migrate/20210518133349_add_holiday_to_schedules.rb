# frozen_string_literal: true

class AddHolidayToSchedules < ActiveRecord::Migration[5.2]
  def change
    add_column :schedules, :holidays, :boolean
    add_column :schedule_histories, :holidays, :boolean
  end
end
