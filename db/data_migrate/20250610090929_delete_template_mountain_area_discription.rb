# frozen_string_literal: true

class DeleteTemplateMountainAreaDiscription < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    things = DataCycleCore::Thing.where(template_name: 'MountainAreaDiscription')
    return if things.present?
    execute <<~SQL.squish
      UPDATE public.things
      SET template_name = 'MountainAreaDescription'
      WHERE template_name = 'MountainAreaDiscription';
    SQL

    execute <<~SQL.squish
      UPDATE public.thing_histories
      SET template_name = 'MountainAreaDescription'
      WHERE template_name = 'MountainAreaDiscription';
    SQL

    execute <<~SQL.squish
      DELETE FROM public.thing_templates
      WHERE template_name = 'MountainAreaDiscription';
    SQL
  end

  def down
  end
end
