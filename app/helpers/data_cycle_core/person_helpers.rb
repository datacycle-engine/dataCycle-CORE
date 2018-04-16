module DataCycleCore
  module PersonHelpers
    def title
      "#{given_name} #{family_name}"
    end

    def desc
      content['job_title']
    end

    def new_content_fields
      ['given_name', 'family_name']
    end
  end
end
