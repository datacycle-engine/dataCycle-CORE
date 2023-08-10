# frozen_string_literal: true

class ValidateForeignKeysForThingsThingTemplates < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    output = execute <<-SQL.squish
      UPDATE things
      SET template_name = NULL
      WHERE NOT EXISTS (
        SELECT 1
        FROM thing_templates
        WHERE thing_templates.template_name = things.template_name
      );
    SQL

    puts "things -> thing_templates (#{output.count})" # rubocop:disable Rails/Output

    output = execute <<-SQL.squish
      UPDATE thing_histories
      SET template_name = NULL
      WHERE NOT EXISTS (
        SELECT 1
        FROM thing_templates
        WHERE thing_templates.template_name = thing_histories.template_name
      );
    SQL

    puts "thing_histories -> thing_templates (#{output.count})" # rubocop:disable Rails/Output

    validate_foreign_key :things, :thing_templates
    validate_foreign_key :thing_histories, :thing_templates

    DataCycleCore::RunTaskJob.set(queue: 'importers').perform_later('db:maintenance:vacuum', [true, false, 'things|thing_histories'])
  end

  def down
  end
end
