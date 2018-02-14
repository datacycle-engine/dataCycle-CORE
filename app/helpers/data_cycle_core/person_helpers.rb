module DataCycleCore
  module PersonHelpers
    def title
      "#{given_name} #{family_name}"
    end

    def desc
      content['job_title']
    end
  end
end
