# frozen_string_literal: true

# Not ported to concepts by #41458: both branches rebuild the collected contents through a function
# the cut dropped (generate_collected_cl_content_relations_transitive and
# generate_collected_classification_content_relations), so every database old enough to need it has
# already recorded this migration as run.
class FixCccAgain < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    return say('the pre-concept classification tables are gone (see #41458); nothing to migrate') unless table_exists?(:classification_aliases)

    if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
      execute <<~SQL.squish
        SET LOCAL statement_timeout = 0;

        SELECT public.generate_collected_cl_content_relations_transitive (array_agg(things.id))
        FROM things;
      SQL
    else
      execute <<~SQL.squish
        SET LOCAL statement_timeout = 0;

        SELECT public.generate_collected_classification_content_relations (array_agg(things.id), ARRAY[]::UUID[])
        FROM things;
      SQL
    end
  end

  def down
  end
end
