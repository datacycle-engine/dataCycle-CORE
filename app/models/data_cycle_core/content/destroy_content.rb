# frozen_string_literal: true

module DataCycleCore
  module Content
    module DestroyContent
      def destroy_content(current_user: nil, save_time: Time.zone.now)
        children.each { |item| item.destroy_content(current_user: current_user, save_time: save_time) } if respond_to?(:children)
        unless history?
          set_deleted_by(current_user, save_time)
          to_history(save_time: save_time, current_user: current_user, delete: true)
        end
        destroy_children
      end

      def set_deleted_by(current_user, save_time)
        to_update_data = { 'deleted_by' => [current_user.presence&.id].compact, 'date_deleted' => save_time }
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
