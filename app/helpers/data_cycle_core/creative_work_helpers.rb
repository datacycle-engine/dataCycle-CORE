module DataCycleCore
  module CreativeWorkHelpers
    def title
      headline
    end

    def desc
      description
    end

    def new_content_fields
      ['headline']
    end

    def object_browser_fields
      ['headline']
    end
  end
end
