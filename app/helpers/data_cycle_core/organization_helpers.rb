module DataCycleCore
  module OrganizationHelpers
    def title
      content['legal_name']
    end

    def desc
      description
    end
  end
end
