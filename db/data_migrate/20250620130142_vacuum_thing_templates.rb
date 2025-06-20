# frozen_string_literal: true

class VacuumThingTemplates < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(wait_until: Time.zone.now.change(hour: 19), queue: 'importers').perform_later('db:maintenance:vacuum', [true, 'thing_templates'])
  end

  def down
  end
end
