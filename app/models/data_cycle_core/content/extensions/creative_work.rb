# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module CreativeWork
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
  end
end