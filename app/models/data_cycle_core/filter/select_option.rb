# frozen_string_literal: true

module DataCycleCore
  module Filter
<<<<<<< HEAD
    SelectOption = Struct.new(:id, :name, :html_class, :title) do
=======
    SelectOption = Struct.new(:id, :name, :html_class, :dc_tooltip, :disabled, :data) do
      def initialize(*)
        super

        self.data ||= {}
        self.disabled = false if disabled.nil?
      end

>>>>>>> old/develop
      def to_option_for_select
        [
          name&.to_str,
          id,
          {
            class: html_class,
<<<<<<< HEAD
            title: title
=======
            disabled: disabled,
            data: data.merge({
              dc_tooltip: dc_tooltip
            })
>>>>>>> old/develop
          }
        ]
      end
    end
  end
end
