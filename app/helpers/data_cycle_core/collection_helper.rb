# frozen_string_literal: true

module DataCycleCore
  module CollectionHelper
    def get_collection_groups(local_assigns, include_data_hashes = false)
      collection_group_index = local_assigns[:collection_group_index] || 0

      if local_assigns[:collection_group].present?
        group_title = local_assigns.dig(:collection_group, 0)
        collections = local_assigns.dig(:collection_group, 1)
        collection_groups = collections.group_by { |c| c.full_path_names[collection_group_index] }
        nested = true
      else
        collections = DataCycleCore::WatchList.accessible_by(current_ability).includes(:valid_write_links, :watch_list_shares, :user)
        collections = collections.includes(:watch_list_data_hashes) if include_data_hashes
        collections = collections.fulltext_search(local_assigns[:q]) if local_assigns[:q].present?
        collections = collections.order(updated_at: :desc)
        collection_groups = collections.group_by { |c| c.full_path_names[collection_group_index] }
      end

      return collections, collection_groups, collection_group_index + 1, nested, group_title
    end

    def has_selected_collections?(collections, content_id)
      collections.any? { |c| c.watch_list_data_hashes.any? { |w| w.hashable_id == content_id && w.hashable_type == 'DataCycleCore::Thing' } }
    end
  end
end
