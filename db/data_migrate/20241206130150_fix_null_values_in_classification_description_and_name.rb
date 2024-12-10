# frozen_string_literal: true

class FixNullValuesInClassificationDescriptionAndName < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE classification_aliases
      SET description_i18n = '{}'
      WHERE classification_aliases.description_i18n IS NULL;

      UPDATE classification_aliases
      SET name_i18n = '{}'
      WHERE classification_aliases.name_i18n IS NULL;
    SQL
  end

  def down
  end
end
