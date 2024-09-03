# frozen_string_literal: true

class RemoveLegacyPostgresFunctions < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP FUNCTION IF EXISTS public.generate_classification_alias_paths(uuid[]);
    SQL
  end

  def down
  end
end
