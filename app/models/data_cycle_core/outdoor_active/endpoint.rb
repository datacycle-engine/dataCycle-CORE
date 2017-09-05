module DataCycleCore::OutdoorActive
  class Endpoint
    def initialize(project: nil, key: nil)
      @project = project
      @key = key
    end

    def load_categories(lang: :de)
      response = Faraday.new.get do |req|
        req.url File.join('http://www.outdooractive.com', 'api', 'project', @project, 'category', 'tree')

        req.headers['Accept'] = 'application/json'

        req.params['key'] = @key
        req.params['lang'] = lang
      end

      JSON.parse(response.body)['category']
    end
  end
end
