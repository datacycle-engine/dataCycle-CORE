# frozen_string_literal: true

class AddOrderToContentContentsTable < ActiveRecord::Migration[5.0]
  def up
    add_column :content_contents, :order_a, :integer
    add_column :content_contents, :order_b, :integer
    remove_column :content_contents, :external_source_id, :uuid

    add_column :content_content_histories, :order_a, :integer
    add_column :content_content_histories, :order_b, :integer
    remove_column :content_content_histories, :external_source_id, :uuid
  end

  def down
    remove_column :content_contents, :order_a, :integer
    remove_column :content_contents, :order_b, :integer
    add_column :content_contents, :external_source_id, :uuid

    remove_column :content_content_histories, :order_a, :integer
    remove_column :content_content_histories, :order_b, :integer
    add_column :content_content_histories, :external_source_id, :uuid
  end
end
