# frozen_string_literal: true

class AddIndexForContentContentLinksContentBId < ActiveRecord::Migration[6.1]
  def change
    add_index :content_content_links, :content_b_id, if_not_exists: true
  end
end
