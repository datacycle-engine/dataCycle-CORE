# frozen_string_literal: true

class AddIndexToContentContents < ActiveRecord::Migration[5.2]
  def change
    add_index :content_contents, :content_b_id
  end
end
