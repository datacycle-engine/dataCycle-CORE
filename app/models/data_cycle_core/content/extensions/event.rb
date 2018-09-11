# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Event
        def title
          # TODO: remove later
          return name if respond_to?(:name) && name.present?
          headline if respond_to?(:headline) && headline.present?
        end

        def desc
          description
        end

        def new_content_fields
          ['name']
        end

        def object_browser_fields
          ['name']
        end
      end
    end
  end
end
