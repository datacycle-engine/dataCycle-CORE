# frozen_string_literal: true

module DataCycleCore
  module Update
    module UpdateTemplate
      def query
        @type.where(template: false)
          .where(@type.arel_table[:template_name].eq(@template.template_name))
      end

      def read(_)
        {}
      end

      def modify_content(content_item)
        content_item.template_name = @template.template_name
        content_item.schema = @template.schema
        I18n.with_locale(content_item.available_locales.first) do
          content_item.save(touch: false)
        end
      end

      def write(_, _, _)
        {}
      end
    end
  end
end
