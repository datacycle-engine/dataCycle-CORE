# frozen_string_literal: true

class AddDefaultDummyTranslationValuesForAllTemplates < ActiveRecord::Migration[8.0]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    templates = DataCycleCore::ThingTemplate.without_embedded.pluck(:template_name)
    return if templates.blank?

    DataCycleCore::RunTaskJob.perform_later('dc:update_data:add_defaults', [templates.join('|'), false, 'dummy'])
  end

  def down
  end
end
