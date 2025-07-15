# frozen_string_literal: true

module DataCycleCore
  module Filter
    SelectOption = Struct.new(:id, :name, :html_class, :dc_tooltip, :disabled, :class_key, keyword_init: true) do
      def initialize(*)
        super

        self.disabled = false if disabled.nil?
      end

      def to_option_for_select
        [
          name&.to_str,
          id,
          {
            class: html_class,
            disabled:,
            data: {
              dc_tooltip:
            }
          }
        ]
      end
    end
  end
end
