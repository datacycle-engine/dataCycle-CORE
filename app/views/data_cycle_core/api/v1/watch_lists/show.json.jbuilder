json.watch_list do
  json.set! 'id', @watch_list.id
  json.set! 'user_id', @watch_list.user_id
  json.partial! 'items', locals: {item: @watch_list }
end
