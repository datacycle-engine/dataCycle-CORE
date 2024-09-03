# frozen_string_literal: true

class RebuildSearchForSlug < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('dc:search:migrate_slugs')
  end

  def down
  end
end
