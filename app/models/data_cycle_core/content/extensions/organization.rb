# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Organization
        def title
          content.presence&.dig('legal_name')
        end

        def desc
          description
        end

        def new_content_fields
          ['legal_name']
        end

        def object_browser_fields
          ['legal_name']
        end
      end
    end
  end
end