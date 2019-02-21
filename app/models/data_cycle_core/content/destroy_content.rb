# frozen_string_literal: true

module DataCycleCore
  module Content
    module DestroyContent
      def destroy_content(current_user: nil, save_time: Time.zone.now, save_history: true, destroy_linked: false)
        ActiveRecord::Base.transaction do
          children.each { |item| item.destroy_content(current_user: current_user, save_time: save_time) } if respond_to?(:children)
          unless history? || !save_history
            self.deleted_at = save_time
            self.deleted_by = current_user&.id
            to_history(save_time: save_time, delete: true)
          end
          destroy_children
          destroy_linked_data(current_user: current_user, save_time: save_time, save_history: save_history, destroy_linked: destroy_linked) if external_source_id.present? && destroy_linked
          destroy
        end
        run_callbacks(:destroyed_data_hash) unless history?
      end

      def destroy_children
        embedded_property_names.each do |name|
          load_embedded_objects(name).each do |item|
            item.destroy_children
            item.destroy
          end
        end
        asset_property_names.each do |name|
          load_asset_relation(name).each(&:destroy)
        end
      end

      def destroy_linked_data(current_user:, save_time:, save_history:, destroy_linked:)
        linked_property_names.each do |name|
          load_linked_objects(name).each do |item|
            next if item.external_source.id.blank?
            next if DataCycleCore::ContentContent.where(content_a_id: item.id).or(DataCycleCore::ContentContent.where(content_b_id: item.id)).pluck(:content_a_id).uniq.count > 1
            item.destroy_content(current_user: current_user, save_time: save_time, save_history: save_history, destroy_linked: destroy_linked)
          end
        end
      end
    end
  end
end
