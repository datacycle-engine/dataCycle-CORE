module DataCycleCore
  module EventHelpers
    def title
      # TODO: remove later
      name if respond_to?(:name)
      headline if respond_to?(:headline)
    end

    def desc
      description
    end

    def new_content_fields
      ['name']
    end
  end
end
