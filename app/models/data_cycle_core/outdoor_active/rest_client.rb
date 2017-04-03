module DataCycleCore
  module OutdoorActive

    class RestClient < DataCycleCore::RestClient

      def setup_credentials(credentials)
        # implement credentials setup and store values for later usage
        verification = false
        unless credentials.blank?
          if credentials.has_key?('project') && credentials.has_key?('key')
            verification = true
            @project=credentials['project']
            @key=credentials['key']
          end
        end
        return verification
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
