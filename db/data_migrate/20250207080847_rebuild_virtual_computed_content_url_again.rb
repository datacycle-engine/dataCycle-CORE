# frozen_string_literal: true

class RebuildVirtualComputedContentUrlAgain < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('dc:update_data:computed_attributes', ['Bild|PDF|ImageObject', false, 'virtual_content_url|virtual_thumbnail_url|virtual_web_url|virtual_web_small_url|virtual_dynamic_url'])
  end

  def down
  end
end
