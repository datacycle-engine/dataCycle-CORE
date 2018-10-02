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
            name
          when 'Person'
            "#{given_name} #{family_name}"
          end
        end

        def desc
          case schema_type
          when 'Organization'
            description
          when 'Person'
            content['job_title']
          end
        end

        def new_content_fields
          case schema_type
          when 'Organization'
            ['name']
          when 'Person'
            ['given_name', 'family_name']
          end
        end

        def object_browser_fields
          case schema_type
          when 'Organization'
            []
          when 'Person'
            ['given_name', 'family_name', 'honorific_prefix', 'job_title', 'contact_info']
          end
        end
      end
    end
  end
end
