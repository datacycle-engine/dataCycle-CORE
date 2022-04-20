# frozen_string_literal: true

module DataCycleCore
  module Filter
    SelectOption = Struct.new(:id, :name, :html_class, :dc_tooltip, :data) do
      def initialize(*)
        super

        self.data ||= {}
      end

      def to_option_for_select
        [
          name&.to_str,
          id,
          {
            class: html_class,
            data: data.merge({
              dc_tooltip: dc_tooltip
            })
          }
        ]
      end
    end
  end
end
