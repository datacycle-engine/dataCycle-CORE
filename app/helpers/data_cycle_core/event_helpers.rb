module DataCycleCore
  module EventHelpers
    def title
      name
    end

    def desc
      description
    end

    def new_content_fields
      ['name']
    end
  end
end
