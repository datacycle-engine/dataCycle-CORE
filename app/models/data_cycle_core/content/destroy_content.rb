# frozen_string_literal: true

module DataCycleCore
  module Content
    module DestroyContent
      def destroy(current_user: nil, save_time: Time.zone.now, save_history: true, destroy_locale: false, destroy_linked: nil, destroyed_ancestors: [])
        return self if destroy_locale && available_locales.exclude?(I18n.locale)
        return self if destroyed_ancestors.include?(id)

        current_user ||= parent&.deleted_by_user if respond_to?(:parent)

        transaction(joinable: false, requires_new: true) do
          new_destroyed_ancestors = destroyed_ancestors + [id]

          if save_history && !history?
            update_columns(deleted_at: save_time, deleted_by: current_user&.id)
            to_history(delete: true, all_translations: !(destroy_locale && available_locales.many?))
          end

          destroy_children(current_user:, save_time:, destroy_linked:, destroy_locale:, destroyed_ancestors: new_destroyed_ancestors)
          if destroy_locale && available_locales.many?
            destroy_translation(I18n.locale)
            after_save_data_hash(DataCycleCore::Content::DataHashOptions.new(current_user:, save_time:)) unless history?
          else
            before_destroy_data_hash(DataCycleCore::Content::DataHashOptions.new(current_user:, save_time:)) unless history?
            destroy_linked_data(current_user:, save_time:, save_history:, destroy_linked:, destroyed_ancestors: new_destroyed_ancestors) if destroy_linked.is_a?(::Hash)
            super()
          end
        end

        self
      end

      alias destroy_content destroy

      def destroy_children(current_user: nil, save_time: Time.zone.now, destroy_linked: nil, destroy_locale: false, destroyed_ancestors: [])
        embedded_property_names.each do |name|
          load_embedded_objects(name, nil, destroy_locale).each do |item|
            if destroy_locale && item.available_locales.many?
              item.destroy_children(current_user:, save_time:, destroy_linked:, destroy_locale:, destroyed_ancestors:)
              item.destroy_translation(I18n.locale)
            else
              item.destroy(current_user:, save_time:, save_history: false, destroy_linked:, destroy_locale:, destroyed_ancestors:)
            end
          end
        end

        # update update references from DataCycleCore::ContentContent::History to DataCycleCore::Thing
        return if (destroy_locale && available_locales.many?) || history?

        asset_contents&.destroy_all

        last_history_entry = histories.where.not(deleted_at: nil)&.first
        return if last_history_entry.blank?
        DataCycleCore::ContentContent::History
          .where(content_b_history_id: id, content_b_history_type: self.class.to_s)
          .update_all(content_b_history_id: last_history_entry.id, content_b_history_type: last_history_entry.class.to_s)
      end

      def destroy_linked_data(current_user:, save_time:, save_history:, destroy_linked:, destroyed_ancestors: [])
        return if destroy_linked.blank?

        collection_ids, template_names, external_system_ids = destroy_linked.with_indifferent_access.values_at(:collection_ids, :template_names, :external_system_ids)

        return if collection_ids.blank? && template_names.blank?

        content_b.includes(:content_content_b).find_each do |item|
          next if item.content_content_b.any? { |cc| cc.content_a_id != id }

          if collection_ids.present?
            filter = DataCycleCore::StoredFilter.new.parameters_from_hash([union_filter_ids: collection_ids])
            next unless filter.things.exists?(item.id)
          else
            next if template_names.exclude?(item.template_name)
            next if external_system_ids.present? && external_system_ids.exclude?(item.external_source_id)
            next if external_system_ids.blank? && item.external_source_id != external_source_id
          end

          item.destroy(current_user:, save_time:, save_history:, destroy_linked:, destroyed_ancestors:)
        end
      end

      def destroy_translation(locale)
        translations.in_locale(locale)&.destroy
        searches.where(locale:).delete_all
        translations.reload # (rails cache still includes removed translations)
      end
    end
  end
end
