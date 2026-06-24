# frozen_string_literal: true

class RemoveSlugTriggersForCollections < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS generate_collection_slug_trigger ON public.collections;
      DROP TRIGGER IF EXISTS update_collection_slug_trigger ON public.collections;
      DROP FUNCTION IF EXISTS public.generate_collection_slug_trigger();
      DROP FUNCTION IF EXISTS public.generate_unique_collection_slug(character varying);
    SQL
  end

  def down
  end
end
