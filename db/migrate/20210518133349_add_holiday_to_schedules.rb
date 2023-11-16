# frozen_string_literal: true

class AddHolidayToSchedules < ActiveRecord::Migration[5.2]
  def change
    add_column :schedules, :holidays, :boolean # rubocop:disable Rails/ThreeStateBooleanColumn
    add_column :schedule_histories, :holidays, :boolean # rubocop:disable Rails/ThreeStateBooleanColumn
  end
end
