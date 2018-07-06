# frozen_string_literal: true

json.meta do
  json.total objects.total_count
end

json.links do
  json.self object_url.call(page: { number: objects.current_page, size: objects.limit_value })
  json.first object_url.call(page: { number: 1, size: objects.limit_value }) unless objects.first_page?
  json.prev object_url.call(page: { number: objects.prev_page, size: objects.limit_value }) if objects.prev_page && !objects.first_page?
  json.next object_url.call(page: { number: objects.next_page, per: objects.limit_value }) if objects.next_page && !objects.last_page?
  json.last object_url.call(page: { number: objects.total_pages, per: objects.limit_value }) unless objects.last_page?
end
