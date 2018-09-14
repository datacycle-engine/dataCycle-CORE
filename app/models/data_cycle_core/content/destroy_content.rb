# frozen_string_literal: true

module DataCycleCore
  module Content
    module DestroyContent
      def destroy_content(current_user: nil, save_time: Time.zone.now)
        ActiveRecord::Base.transaction do
          children.each { |item| item.destroy_content(current_user: current_user, save_time: save_time) } if respond_to?(:children)
          unless history?
            set_deleted_by(current_user, save_time)
            to_history(save_time: save_time, delete: true)
          end
          destroy_children
          destroy
        end
      end

      def set_deleted_by(current_user, save_time)
        to_update_data = nil
        to_update_data = { 'date_deleted' => save_time } if property_names.include?('date_deleted')
        to_update_data = to_update_data.merge('deleted_by' => [current_user&.id].compact) if current_user.present? && property_names.include?('deleted_by')
        return if to_update_data.blank?
        set_data_hash(data_hash: to_update_data, current_user: current_user, save_time: save_time, prevent_history: true, update_search_all: false, partial_update: true)
      end

      def destroy_children
        embedded_property_names.each do |name|
          definition = property_definitions[name]

          delete = false
          delete = true if history? || definition['type'] == 'embedded'
          next unless delete

          load_embedded_objects(name).each do |item|
            item.destroy_children
            item.destroy
          end
        end
      end
    end
  end
end
