module DataCycleCore
  module ContentHelpers
    def content_type
      metadata['validation']['name']
    end

    def title
      headline || (content ? content['headline'] : '')
    end

    def creator
      nil
    end
  end
end
