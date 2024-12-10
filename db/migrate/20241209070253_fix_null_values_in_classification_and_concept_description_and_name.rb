# frozen_string_literal: true

class FixNullValuesInClassificationAndConceptDescriptionAndName < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      UPDATE classification_aliases
      SET description_i18n = '{}'
      WHERE classification_aliases.description_i18n IS NULL;

      UPDATE classification_aliases
      SET name_i18n = '{}'
      WHERE classification_aliases.name_i18n IS NULL;
    SQL

    change_table(:classification_aliases, bulk: true) do |t|
      t.change_null :name_i18n, false
      t.change_null :description_i18n, false
    end
  end

  def down
  end
end
