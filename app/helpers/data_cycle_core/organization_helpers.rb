module DataCycleCore
  module OrganizationHelpers
    def title
      content['legal_name']
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
