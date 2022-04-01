# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Preview < Base
      class << self
        def available_widgets
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym, :widgets).reject { |_, v| v.blank? }
        end
      end
    end
  end
end
