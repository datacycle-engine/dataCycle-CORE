# frozen_string_literal: true

class ChangeDataLinks < ActiveRecord::Migration[5.0]
  def up
    execute 'DELETE FROM data_links'
    add_column :data_links, :receiver_id, :uuid
    add_column :data_links, :comment, :text
    add_column :data_links, :valid_from, :datetime
    add_column :data_links, :valid_until, :datetime
  end

  def down
    remove_column :data_links, :receiver_id
    remove_column :data_links, :comment
    remove_column :data_links, :valid_from
    remove_column :data_links, :valid_until
  end
end
