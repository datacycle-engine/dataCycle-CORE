# frozen_string_literal: true

module DataCycleCore
  class PartialRenderService
    include Singleton

    def render(partial:, **kwargs)
      ApplicationController.render(partial: partial, layout: false, **kwargs)
    end
  end
end
