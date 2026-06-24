# frozen_string_literal: true

class AddIndexForIdAttributeHashToContentContentLinks < ActiveRecord::Migration[8.0]
  def up
    execute('SET LOCAL statement_timeout = 0;')

    add_index :content_content_links, [:content_b_id, :relation, :content_a_id], name: 'index_ccl_on_content_b_id_relation_content_a_id'
    add_index :delayed_jobs, [:queue, :failed_at], name: 'index_dj_on_queue_failed_at'
  end

  def down
    remove_index :content_content_links, name: 'index_ccl_on_content_b_id_relation_content_a_id'
    remove_index :delayed_jobs, name: 'index_dj_on_queue_failed_at'
  end
end
