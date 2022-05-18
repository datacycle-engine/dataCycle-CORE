# frozen_string_literal: true

module DataCycleCore
  module Filter
    SelectOption = Struct.new(:id, :name, :html_class, :title) do
      def to_option_for_select
        [
          name&.to_str,
          id,
          {
            class: html_class,
            title: title
          }
        ]
      end
    end
  end
end
