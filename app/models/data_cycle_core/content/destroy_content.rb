# frozen_string_literal: true

module DataCycleCore
  module Content
    module DestroyContent
      def destroy_content(current_user: nil, save_time: Time.zone.now, save_history: true, destroy_locale: false, destroy_linked: false)
        return if destroy_locale && !available_locales.include?(I18n.locale)
        ActiveRecord::Base.transaction do
          children.each { |item| item.destroy_content(current_user: current_user, save_time: save_time) } if respond_to?(:children)
          if save_history && !history?
            self.deleted_at = save_time
            self.deleted_by = current_user&.id
            to_history(save_time: save_time, delete: true)
          end

          destroy_children(current_user: current_user, save_time: save_time, destroy_linked: destroy_linked, destroy_locale: destroy_locale)
          destroy_linked_data(current_user: current_user, save_time: save_time, save_history: save_history, destroy_linked: destroy_linked) if destroy_linked
          if destroy_locale && available_locales.many?
            destroy_translation(I18n.locale)
          else
            destroy
          end
        end
        if destroyed?
          run_callbacks(:destroyed_data_hash) unless history?
        else
          run_callbacks(:saved_data_hash) unless history?
        end
        self
      end

      def destroy_children(current_user: nil, save_time: Time.zone.now, destroy_linked: false, destroy_locale: false)
        embedded_property_names.each do |name|
          load_embedded_objects(name, destroy_locale).each do |item|
            if destroy_locale && item.available_locales.many?
              item.destroy_children(current_user: current_user, save_time: save_time, destroy_linked: destroy_linked, destroy_locale: destroy_locale)
              item.destroy_translation(I18n.locale)
            else
              item.destroy_content(current_user: current_user, save_time: save_time, save_history: false, destroy_linked: destroy_linked, destroy_locale: destroy_locale)
            end
          end
        end
        asset_property_names.each do |name|
          load_asset_relation(name)&.destroy
        end
      end

      def destroy_linked_data(current_user:, save_time:, save_history:, destroy_linked:)
        linked_property_names.each do |name|
          properties = properties_for(name)
          next if properties.dig('link_direction') == 'inverse'
          load_linked_objects(name).each do |item|
            next if number_of_unique_links(item.id) > 1
            item.destroy_content(current_user: current_user, save_time: save_time, save_history: save_history, destroy_linked: destroy_linked)
          end
        end
      end

      def number_of_unique_links(item_id)
        (
          DataCycleCore::ContentContent.where(content_a_id: item_id).pluck(:content_b_id) +
          DataCycleCore::ContentContent.where(content_b_id: item_id).pluck(:content_a_id)
        ).uniq.size
      end

      def destroy_translation(locale)
        translations.in_locale(locale).destroy
        translations.reload # bug of Globalize (does not invalidate query cache)
      end
    end
  end
end
