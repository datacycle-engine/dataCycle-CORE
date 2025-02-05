# frozen_string_literal: true

class RemoveEmptyThingTranslations < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      DELETE FROM thing_translations WHERE thing_translations.content IS NULL;
    SQL

    DataCycleCore::RunTaskJob.perform_later('dc:update_data:add_missing_slugs')
  end

  def down
  end
end
