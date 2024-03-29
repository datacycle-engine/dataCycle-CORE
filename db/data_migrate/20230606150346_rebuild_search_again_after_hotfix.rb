# frozen_string_literal: true

class RebuildSearchAgainAfterHotfix < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('dc:update:search:rebuild') unless Rails.env.development?
  end

  def down
  end
end
