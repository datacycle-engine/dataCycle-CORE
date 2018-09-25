# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Thing
        def schema_type
          schema&.dig('schema_type')
        end

        def title
          case schema_type
          when 'Organization'
            content.presence&.dig('legal_name')
          end
        end

        def desc
          case schema_type
          when 'Organization'
            description
          end
        end

        def new_content_fields
          case schema_type
          when 'Organization'
            ['name']
          end
        end

        def object_browser_fields
          case schema_type
          when 'Organization'
            ['name']
          end
        end
      end
    end
  end
end
