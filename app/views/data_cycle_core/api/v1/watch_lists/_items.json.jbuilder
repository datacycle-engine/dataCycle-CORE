json.set! 'watch_list_items', DataCycleCore::WatchListService.get_objects_with_types(item.watch_list_data_hashes).map { |entry|
  value = entry.get_data_hash
  value.merge!({ '@type' => entry.metadata['validation']['name'] })
  value.compact
}
