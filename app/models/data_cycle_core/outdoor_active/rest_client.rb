module DataCycleCore
  module OutdoorActive

    class RestClient

      def initialize(project,key,verbose=false)
        @project=project
        @key=key
        @conn=Faraday.new(:url => 'http://www.outdooractive.com/') do |faraday|
          faraday.response :logger if verbose       # write requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
        return self
      end

      def get_category_tree
        get "api/project/#{@project}/category/tree/"
      end

      def get_region_tree
        get "api/project/#{@project}/region/tree/"
      end

      def get_poi_tour_index(end_point, lang = nil)
        get "api/project/#{@project}/#{end_point}/", lang, true, true
      end

      def get_poi_tour_details(data_ids, lang = nil)
        get "api/project/#{@project}/oois/#{data_ids}/", lang, true, true
      end

      def get(url, lang = 'de', fallback = true, date = false)
        @conn.get do |req|
          req.url url
          req.headers['Accept'] = 'application/json'
          req.params['key'] = @key
          req.params['lang'] = lang unless lang.nil?
          req.params['fallback'] = fallback unless lang.nil?
          req.params['lastModifiedAfter'] = '01.01.1970' if date
        end
      end
    end

  end
end
