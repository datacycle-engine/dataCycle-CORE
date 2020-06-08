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

        def documents(*)
          api_flags = [
            'includeCategories', 'includeDocumentInfo', 'includeKeyWords',
            'includeAssetCollections', 'includeLinks', 'includeImageProperties',
            'includePins', 'includeRelations', 'includeReferences', 'includeAllPaths'
          ]

          Enumerator.new do |yielder|
            load_data(end_point: 'documents.api', command: 'getDocuments', flags: ['returnIds'], serializer: :to_hash, options: {}).dig('id').each do |item|
              data = load_data(end_point: 'documents.api', command: 'getDocument', flags: api_flags, serializer: :to_hash, options: { id: item['id'] })
              yielder << data
            end
          end
        end

        def folders(*)
          api_flags = [
            'includeUserPermissions', 'includeAllPermissions', 'includeAllLanguages',
            'includeKeyWords', 'includeDocumentInfo', 'includeCategories'
          ]

          Enumerator.new do |yielder|
            [load_data(end_point: 'folders.api', command: 'getFolders', flags: [], serializer: :to_hash, options: {}).dig('folder')].flatten.each do |item|
              tree_items = walk_folder_tree(item)
              tree_items.each do |id|
                data = load_data(end_point: 'folders.api', command: 'getFolder', flags: api_flags, serializer: :to_hash, options: { id: id })
                yielder << data.dig('folder')
              end
            end
          end
        end

        def walk_folder_tree(item)
          folder_ids = []
          if item.dig('nrOfChildren', '#cdata-section').to_i.positive?
            folder_ids << [item.dig('id', '#cdata-section')]
            [load_data(end_point: 'folders.api', command: 'getFolders', flags: [], serializer: :to_hash, options: { id: item.dig('id', '#cdata-section') }).dig('folder')].flatten.each do |sub_item|
              folder_ids << walk_folder_tree(sub_item)
            end
          else
            folder_ids = [item.dig('id', '#cdata-section')]
          end
          folder_ids.flatten
        end

        def keywords(*)
          api_flags = ['includeAdditionalLang', 'includeUserPermissions', 'includeAllPermissions']

          Enumerator.new do |yielder|
            [load_data(end_point: 'keywords.api', command: 'getKeywords', flags: [], serializer: :to_hash, options: {}).dig('keyword')].flatten.each do |item|
              tree_items = walk_keyword_tree(item)
              tree_items.each do |id|
                yielder << load_data(end_point: 'keywords.api', command: 'getKeyword', flags: api_flags, serializer: :to_hash, options: { id: id })
              end
            end
          end
        end

        def walk_keyword_tree(item)
          folder_ids = []
          if item.dig('nrOfChildren', '#cdata-section').to_i.positive?
            folder_ids << [item.dig('id', '#cdata-section')]
            [load_data(end_point: 'keywords.api', command: 'getKeywords', flags: [], serializer: :to_hash, options: { id: item.dig('id', '#cdata-section') }).dig('keyword')].flatten.each do |sub_item|
              folder_ids << walk_keyword_tree(sub_item)
            end
          else
            folder_ids = [item.dig('id', '#cdata-section')]
          end
          folder_ids.flatten
        end

        def asset_collections(*)
          api_flags = []
          Enumerator.new do |yielder|
            load_data(end_point: 'assetcollections.api', command: 'getAssetCollections', flags: api_flags, serializer: :simple, options: {}).dig('assetcollections', 'assetcollection').each do |item|
              walk_asset_collection_tree(item).each do |asset_collection_record|
                yielder << asset_collection_record
              end
            end
          end
        end

        def walk_asset_collection_tree(item)
          api_flags = []
          asset_collection_data = [item]
          if item.dig('nrOfChildren').to_i.positive?
            [load_data(end_point: 'assetcollections.api', command: 'getAssetCollections', flags: api_flags, serializer: :simple, options: { id: item.dig('id') }).dig('assetcollections', 'assetcollection')].flatten.each do |sub_item|
              asset_collection_data += walk_asset_collection_tree(sub_item)
            end
          end
          asset_collection_data
        end

        def keyword_catalogs(*)
          api_flags = ['includeAdditionalLang']
          Enumerator.new do |yielder|
            load_data(end_point: 'keywords.api', command: 'getKeywordCatalogs', flags: api_flags, serializer: :to_hash, options: {}).dig('keyword').each do |item|
              yielder << item
            end
          end
        end

        def users(*)
          api_flags = []
          Enumerator.new do |yielder|
            load_data(end_point: 'users.api', command: 'getUsers', flags: api_flags, serializer: :simple, options: {}).dig('users', 'user').each do |item|
              yielder << item
            end
          end
        end

        def user_groups(*)
          api_flags = []
          Enumerator.new do |yielder|
            load_data(end_point: 'usergroups.api', command: 'getUserGroups', flags: api_flags, serializer: :simple, options: {}).dig('usergroups', 'usergroup').each do |item|
              yielder << item
            end
          end
        end

        def load_data(end_point:, command:, flags: [], serializer:, options: {})
          url = @url + end_point
          # puts "request: #{@url + end_point} ? command: #{command} & flags=[#{flags.join(', ')}] & options={#{options.map { |key, value| "#{key}=#{value}" }.join(', ')}}"

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
          when :to_hash
            xml_data.children.first.to_hash
          when :simple
            data_hash
          end
        end
      end
    end
  end
end
