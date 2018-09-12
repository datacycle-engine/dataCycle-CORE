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
        set_data_hash_attribute('deleted_by', [current_user.presence&.id].compact, current_user, save_time) if current_user.present?
        set_data_hash_attribute('date_deleted', save_time, current_user, save_time)
        save(touch: false)
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
