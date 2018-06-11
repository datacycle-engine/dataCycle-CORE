# frozen_string_literal: true

module DataCycleCore
  module ContentTranslationHelpers
    def title
      headline || (content ? content['headline'] : '')
    end

    def desc
      description || (content ? content['text'] : '')
    end
  end
end
