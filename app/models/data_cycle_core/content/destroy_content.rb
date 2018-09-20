# frozen_string_literal: true

module DataCycleCore
  module Content
    module DestroyContent
      def destroy_content(current_user: nil, save_time: Time.zone.now)
        ActiveRecord::Base.transaction do
          children.each { |item| item.destroy_content(current_user: current_user, save_time: save_time) } if respond_to?(:children)
          unless history?
            self.deleted_at = save_time
            self.deleted_by = current_user&.id
            to_history(save_time: save_time, delete: true)
          end
          destroy_children
          destroy
        end
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
