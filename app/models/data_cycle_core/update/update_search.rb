# frozen_string_literal: true

module DataCycleCore
  module Update
    module UpdateSearch
      def query
        @type
          .where(@type.arel_table[:template_name].eq(@template.template_name))
      end

      def read(_)
        {}
      end

      def modify_content(content_item)
        content_item.translated_locales.each do |lang|
          content_item.update_search lang
        end
      end

      def write(_, _, _)
        {}
      end
    end
  end
end
