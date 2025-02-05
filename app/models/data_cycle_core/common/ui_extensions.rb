# frozen_string_literal: true

module DataCycleCore
  module Common
    module UiExtensions
      def icon_class
        self.class.name.demodulize.underscore_blanks
      end
    end
  end
end
