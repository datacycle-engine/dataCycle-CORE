module DataCycleCore
  module Update
    module UpdateSearch
      def query
        @type.where(template: false)
          .where(@type.arel_table[:template_name].eq(@template.template_name))
      end

      def read(_)
        {}
      end

      def modify_content(content_item)
        content_item.available_locales.each do |lang|
          I18n.with_locale(lang) do
            content_item.set_search
          end
        end
      end

      def write(_, _, _)
        {}
      end
    end
  end
end
