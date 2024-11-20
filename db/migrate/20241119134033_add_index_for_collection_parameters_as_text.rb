# frozen_string_literal: true

class AddIndexForCollectionParametersAsText < ActiveRecord::Migration[7.1]
  def up
    # used for merging concepts
    execute <<-SQL.squish
      CREATE INDEX IF NOT EXISTS index_collections_on_parameters ON public.collections USING gin ((parameters::TEXT) gin_trgm_ops);
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP INDEX IF EXISTS index_collections_on_parameters;
    SQL
  end
end
