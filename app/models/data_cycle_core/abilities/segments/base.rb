# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class Base
        attr_reader :user, :session

        def to_s
          I18n.translate("abilities.segments.#{self.class.name.demodulize.underscore}", locale: user&.ui_locale || DataCycleCore.ui_locales.first)
        end
      end
    end
  end
end
