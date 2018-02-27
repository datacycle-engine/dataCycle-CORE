module DataCycleCore
  module OrganizationHelpers
    def title
      name
    end

    def desc
      content['legalName']
    end
  end
end
