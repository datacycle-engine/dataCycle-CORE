# frozen_string_literal: true

module DataCycleCore
  module CollectionHelper
    BulkUpdateType = Struct.new(:value, :text, :checked)

    def get_collection_groups(local_assigns, include_data_hashes = false)
      collection_group_index = local_assigns[:collection_group_index] || 0

      if local_assigns[:collection_group].present?
        group_title = local_assigns.dig(:collection_group, 0)
        collections = local_assigns.dig(:collection_group, 1)
        nested = true
      else
        collections = DataCycleCore::WatchList.accessible_by(current_ability).includes(:valid_write_links, :watch_list_shares, :user)
        collections = collections.includes(:watch_list_data_hashes) if include_data_hashes
        collections = collections.fulltext_search(local_assigns[:q]) if local_assigns[:q].present?
        collections = collections.order(updated_at: :desc)
      end

      if DataCycleCore::Feature::CollectionGroup.enabled?
        collection_groups = collections.group_by { |c| c.full_path_names&.dig(collection_group_index) }
      else
        collection_groups = { nil => collections }
      end

      return collections, collection_groups, collection_group_index + 1, nested, group_title
    end

    def selected_collections?(collections, content_id)
      collections.any? { |c| c.watch_list_data_hashes.any? { |w| w.hashable_id == content_id && w.hashable_type == 'DataCycleCore::Thing' } }
    end

    def bulk_update_types(prop)
      check_boxes = [
        BulkUpdateType.new('override', t('common.bulk_update.check_box_labels.override_html', locale: DataCycleCore.ui_language, data: prop['label']))
      ]

      return check_boxes unless prop['type'] == 'classification' && prop.dig('ui', 'edit', 'type').blank? && prop.dig('ui', 'edit', 'options', 'multiple').nil?

      check_boxes.concat(
        [
          BulkUpdateType.new('add', t('common.bulk_update.check_box_labels.add_html', locale: DataCycleCore.ui_language, data: prop['label'])),
          BulkUpdateType.new('remove', t('common.bulk_update.check_box_labels.remove_html', locale: DataCycleCore.ui_language, data: prop['label']))
        ]
      )
    end
  end
end
