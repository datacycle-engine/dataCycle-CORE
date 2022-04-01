# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class Base
        # dynamic scopes or permissions have to be implemented as instance methods, as user and session are nil during initialization (can't be used in initialize method)

        attr_reader :user, :session

        def to_s
          I18n.t("abilities.segments.#{self.class.name.demodulize.underscore}", locale: user&.ui_locale || DataCycleCore.ui_locales.first)
        end
      end
    end
  end
end
