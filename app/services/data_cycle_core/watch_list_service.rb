# frozen_string_literal: true

module DataCycleCore
  class WatchListService
    def self.get_objects_with_types(watch_list_data_hash)
      objects = []
      watch_list_data_hash.each do |data_hash|
        objects.push(data_hash.hashable_type.constantize.includes(:translations, :display_classification_aliases).find_by(id: data_hash.hashable_id))
      end
      objects
    end
  end
end
