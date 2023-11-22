# frozen_string_literal: true

module DataCycleCore
  module Update
    module UpdateData
      def query
        @type
          .where(@type.arel_table[:template_name].eq(@template.template_name))
      end

      def read(content_item)
        data_hash = content_item.get_data_hash
        data_hash = @transformation.call(data_hash) unless @transformation.nil?
        data_hash
      end

      def modify_content(content_item)
        content_item.template_name = @template.template_name
        content_item.save
      end

      def write(content_item, data_hash, timestamp)
        content_item.set_data_hash(data_hash:, save_time: timestamp, prevent_history: true)
      end
    end
  end
end
