# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Person
        def title
          "#{given_name} #{family_name}"
        end

        def desc
          content['job_title']
        end

        def new_content_fields
          ['given_name', 'family_name']
        end

        def object_browser_fields
          ['given_name', 'family_name', 'honorific_prefix', 'job_title', 'contact_info']
        end
      end
    end
  end
end
