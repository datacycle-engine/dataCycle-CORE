# frozen_string_literal: true

module DataCycleCore
  module Content
    module DestroyContent
      DEFAULT_DESTROY_ARGS = {
        current_user: nil,
        save_history: true,
        destroy_locale: false,
        destroy_linked: nil,
        destroyed_ids: []
      }.freeze

      def destroy_opts(opts, kwargs)
        DEFAULT_DESTROY_ARGS.merge(opts).merge(kwargs).tap do |options|
          options[:save_time] ||= Time.zone.now
          options[:current_user] ||= parent&.deleted_by_user if respond_to?(:parent)
        end
      end

      def destroy(options = {}, **kwargs)
        opts = destroy_opts(options, kwargs)
        return self if opts[:destroy_locale] && available_locales.exclude?(I18n.locale)
        return self if opts[:destroyed_ids].include?(id)

        transaction(joinable: false, requires_new: true) do
          if opts[:save_history] && !history? && !embedded?
            update_columns(deleted_at: opts[:save_time], deleted_by: opts[:current_user]&.id)
            to_history(delete: true, all_translations: !(opts[:destroy_locale] && available_locales.many?))
          end

          destroy_children(opts, destroyed_ids: opts[:destroyed_ids] + [id])

          if opts[:destroy_locale] && available_locales.many?
            return self unless destroy_thing_translation?(opts)
            destroy_thing_translation(opts)
          else
            return self unless destroy_thing?(opts)
            destroy_thing(opts)
            super()
          end
        end

        self
      end

      alias destroy_content destroy

      def destroy_children(options = {}, **kwargs)
        opts = destroy_opts(options, kwargs)

        (embedded_property_names - virtual_property_names).each do |name|
          load_embedded_objects(name, nil, opts[:destroy_locale]).each do |item|
            item.destroy(opts)
          end
        end

        # update references from DataCycleCore::ContentContent::History to DataCycleCore::Thing
        return if (opts[:destroy_locale] && available_locales.many?) || history?

        asset_contents&.destroy_all

        last_history_entry = histories.where.not(deleted_at: nil)&.first
        return if last_history_entry.blank?
        DataCycleCore::ContentContent::History
          .where(content_b_history_id: id, content_b_history_type: self.class.to_s)
          .update_all(content_b_history_id: last_history_entry.id, content_b_history_type: last_history_entry.class.to_s)
      end

      def destroy_linked_data(options = {}, **kwargs)
        opts = destroy_opts(options, kwargs)
        return unless opts[:destroy_linked].is_a?(::Hash) && opts[:destroy_linked].present?

        collection_ids, template_names, external_system_ids = opts[:destroy_linked]
          .with_indifferent_access
          .values_at(:collection_ids, :template_names, :external_system_ids)

        return if collection_ids.blank? && template_names.blank?

        content_b.includes(:content_content_b).find_each do |item|
          next if item.content_content_b.any? { |cc| cc.content_a_id != id }

          if collection_ids.present?
            filter = DataCycleCore::StoredFilter.new(parameters: [union_filter_ids: collection_ids])
            next unless filter.things.exists?(item.id)
          else
            next if template_names.exclude?(item.template_name)
            next if external_system_ids.present? && external_system_ids.exclude?(item.external_source_id)
            next if external_system_ids.blank? && item.external_source_id != external_source_id
          end

          item.destroy(opts)
        end
      end

      def destroy_thing?(opts)
        return true unless embedded?

        # embedded should only be destroyed if all parents are destroyed
        !content_content_b
          .where.not(content_a_id: opts[:destroyed_ids])
          .exists?
      end

      def destroy_thing_translation?(opts)
        return true unless embedded?

        # embedded translations should only be destroyed,
        # if all parent translations of the same locale are destroyed
        !content_a
          .where.not(id: opts[:destroyed_ids])
          .joins(:translations)
          .exists?(translations: { locale: I18n.locale })
      end

      def destroy_thing(opts)
        unless history?
          before_destroy_data_hash(
            DataCycleCore::Content::DataHashOptions.new(
              **opts.slice(:current_user, :save_time)
            )
          )
        end

        destroy_linked_data(opts, destroyed_ids: opts[:destroyed_ids] + [id])
      end

      def destroy_thing_translation(opts)
        translations.in_locale(I18n.locale)&.destroy
        searches.where(locale: I18n.locale).delete_all
        translations.reload # (rails cache still includes removed translations)

        return if history?

        after_save_data_hash(
          DataCycleCore::Content::DataHashOptions.new(**opts.slice(:current_user, :save_time))
        )
      end
    end
  end
end
