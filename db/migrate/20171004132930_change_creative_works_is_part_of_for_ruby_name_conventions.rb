# frozen_string_literal: true

class ChangeCreativeWorksIsPartOfForRubyNameConventions < ActiveRecord::Migration[5.0]
  def change
    rename_column :creative_works, :isPartOf, :is_part_of

    rename_column :creative_work_histories, :isPartOf, :is_part_of
  end

  def up
    remove_index :creative_works, :isPartOf
    add_index :creative_works, :is_part_of
  end

  def down
    remove_index :creative_works, :is_part_of
    add_index :creative_works, :isPartOf
  end
end
