# frozen_string_literal: true

class InvalidateCacheAfterTriggerForClassificationMappings < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    Rails.cache.clear
  end

  def down
  end
end
