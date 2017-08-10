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
