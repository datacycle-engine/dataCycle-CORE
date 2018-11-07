# frozen_string_literal: true

json.collection do
  json.set! 'id', @watch_list.id
  json.set! 'name', @watch_list.name
  json.items do
    json.array! @watch_list.watch_list_data_hashes.order(created_at: :desc), partial: 'item', as: :item
  end
end
