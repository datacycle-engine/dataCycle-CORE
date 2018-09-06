# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module ContentTranslation
        def title
          headline || (content ? content['headline'] : '')
        end

        def desc
          description || (content ? content['text'] : '')
        end
      end
    end
  end
end
