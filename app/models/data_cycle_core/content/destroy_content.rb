# frozen_string_literal: true

module DataCycleCore
  module Content
    module DestroyContent
      def destroy_content
        to_history(save_time: Time.zone.now, delete: true) unless history?
        destroy_children
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
