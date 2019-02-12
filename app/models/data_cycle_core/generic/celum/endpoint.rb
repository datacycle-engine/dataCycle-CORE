# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Celum
      class Endpoint
        def initialize(host:, user:, password:, **options)
          @url = host
          @user = user
          @password = password
          @options = options
        end

        def documents(lang: :de)
          api_flags = [
            'includeCategories', 'includeDocumentInfo', 'includeKeyWords',
            'includeAssetCollections', 'includeLinks', 'includeImageProperties',
            'includePins', 'includeRelations', 'includeReferences', 'includeAllPaths'
          ]

          Enumerator.new do |yielder|
            load_data(end_point: 'documents.api', command: 'getDocuments', flags: ['returnIds'], serializer: :index, options: {}).dig('documentIds', 'id').each do |item|
              data = load_data(end_point: 'documents.api', command: 'getDocument', flags: api_flags, serializer: :to_hash, options: { id: item['id'] })
              yielder << data
            end
          end
        end

        def keywords(lang: :de)
          api_flags = ['includeAdditionalLang']
          Enumerator.new do |yielder|
            load_data(end_point: 'keywords.api', command: 'getKeywords', flags: api_flags, serializer: :simple, options: {}).dig('keywords', 'keyword').each do |item|
              yielder << item
            end
          end
        end

        def keyword_catalogs(lang: :de)
          api_flags = ['includeAdditionalLang']
          Enumerator.new do |yielder|
            load_data(end_point: 'keywords.api', command: 'getKeywordCatalogs', flags: api_flags, serializer: :simple, options: {}).dig('keywords', 'keyword').each do |item|
              yielder << item
            end
          end
        end

        def load_data(end_point:, command:, flags: [], serializer:, options: {})
          url = @url + end_point
          puts "request: #{@url + end_point} ? command: #{command} & flags=[#{flags.join(', ')}] & options={#{options.map { |key, value| "#{key}=#{value}" }.join(', ')}}"

          response = Faraday.new.get do |req|
            req.url url
            req.params['username'] = @user
            req.params['password'] = @password
            req.params['command'] = command
            req.params['basicAuthentication'] = true
            flags.each do |flag|
              req.params[flag] = true
            end
            options.each do |name, value|
              req.params[name] = value
            end
          end

          xml_data = Nokogiri::XML(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@url + end_point} ? command: #{command} & flags=[#{flags.join(', ')}] & options={#{options.map { |key, value| "#{key}=#{value}" }.join(', ')}}", response) unless response.success?
          data_hash = Hash.from_xml(xml_data.to_xml)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error_code: #{data_hash.dig('ims', 'error', 'code')} -> #{data_hash.dig('ims', 'error', 'exception', 'message')} from #{@url + end_point} ? command: #{command} & flags=[#{flags.join(', ')}] & options={#{options.map { |key, value| "#{key}=#{value}" }.join(', ')}}", response) if data_hash.dig('ims', 'error').present?
          case serializer
          when :index
            xml_data.children.first.to_hash
          when :to_hash
            xml_data.to_hash
          when :simple
            data_hash
          end
        end
      end
    end
  end
end
