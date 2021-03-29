# frozen_string_literal: true

class RebuildSearch < ActiveRecord::Migration[5.2]
  def up
    return if Rails.env.test?

    DataCycleCore::RunTaskJob.set(queue: 'search_update', wait: 1.hour).perform_later('dc:update:search:rebuild')
  end

  def down
  end
end
