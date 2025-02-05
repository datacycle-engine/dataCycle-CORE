# frozen_string_literal: true

class RebuildCccFromCapt < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    return unless DataCycleCore::Feature::TransitiveClassificationPath.enabled?

    execute <<-SQL.squish
      SET statement_timeout = 0;

      SELECT public.generate_ccc_from_ca_ids_transitive (array_agg(concepts.id))
      FROM concepts;
    SQL
  end

  def down
  end
end
