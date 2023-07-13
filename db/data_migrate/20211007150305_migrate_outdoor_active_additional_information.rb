# frozen_string_literal: true

class MigrateOutdoorActiveAdditionalInformation < ActiveRecord::Migration[5.2]
  def up
    return if Rails.env.test?

    DataCycleCore::RunTaskJob.set(queue: 'importers', wait: 1.hour).perform_later('dc:migrate:oa_external_key')
  end

  def down
  end
end
