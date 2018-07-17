# frozen_string_literal: true

json.set! 'watch_list_items', (DataCycleCore::WatchListService.get_objects_with_types(item.watch_list_data_hashes).map do |entry|
  value = entry.get_data_hash
  value['@type'] = entry.template_name
  value.compact
end)
