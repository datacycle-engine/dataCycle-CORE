json.links do
  json.self object_url.call(page: objects.current_page, per: objects.limit_value)
  json.first object_url.call(page: 1, per: objects.limit_value) unless objects.first_page?
  json.prev object_url.call(page: objects.prev_page, per: objects.limit_value) unless objects.first_page?
  json.next object_url.call(page: objects.next_page, per: objects.limit_value) unless objects.last_page?
  json.last object_url.call(page: objects.total_pages, per: objects.limit_value) unless objects.last_page?
end
