# frozen_string_literal: true

class RecreateBlobChecksums < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(queue: 'search_update').perform_later('dc:assets:rebuild_blob_checksums')
  end

  def down
  end
end
