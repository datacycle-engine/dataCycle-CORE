# frozen_string_literal: true

class AddIndexToContentContentLinkRelation < ActiveRecord::Migration[6.1]
  def change
    add_index(:content_content_links, [:relation, :content_a_id, :content_b_id], if_not_exists: true, name: 'index_ccl_on_relation_content_a_content_b')
  end
end
