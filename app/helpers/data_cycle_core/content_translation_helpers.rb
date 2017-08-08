module DataCycleCore
  module ContentTranslationHelpers
    def title
      headline || (content ? content['headline'] : '')
    end
  end
end
