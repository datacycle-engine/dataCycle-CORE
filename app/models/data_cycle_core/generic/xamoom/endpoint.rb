
# test config for Xamoom
#
# curl -X GET -H 'Content-Type: application/json' -H 'Apikey:25c5606b-a7bf-42e2-85c3-39db1753bc05' 'https://xamoom-api-dot-xamoom-cloud.appspot.com/_api/v2/integration/spots?lang=de'
#
# DataCycleCore::ExternalSource.create!(
#   name: 'Xamoom Klagenfurt',
#   credentials: {
#     'host' => 'https://xamoom-api-dot-xamoom-cloud.appspot.com/',
#     'end_point' => '_api/v2/integration/spots',
#     'key' => '25c5606b-a7bf-42e2-85c3-39db1753bc05'
#   },
#   config: {
#     'download' => 'DataCycleCore::Generic::BatchDownload',
#     'download_config' => {
#       'spots' => {
#         'sorting' => 1,
#         'source_type' => 'spots',
#         'endpoint' => 'DataCycleCore::Generic::Xamoom::Endpoint',
#         'download_strategy' => 'DataCycleCore::Generic::Xamoom::Download',
#         'logging_strategy' => 'DataCycleCore::Generic::Logger::Console.new("download")'
#       }
#     },
#     'import' => 'DataCycleCore::Generic::BatchImport',
#     'import_config' => {
#       'tags' => {
#         'sorting' => 1,
#         'source_type' => 'spots',
#         'import_strategy' => 'DataCycleCore::Generic::Xamoom::ImportTags',
#         'target_type' => 'DataCycleCore::Classification',
#         'tree_label' => 'Xamoom-Tags',
#         'logging_strategy' => 'DataCycleCore::Generic::Logger::Console.new("import")'
#       },
#       'spots' => {
#         'sorting' => 10,
#         'source_type' => 'spots',
#         'import_strategy' => 'DataCycleCore::Generic::Xamoom::ImportSpots',
#         'data_template' => 'Örtlichkeit',
#         'data_type' => 'spot',
#         'image_template' => 'Bild',
#         'target_type' => 'DataCycleCore::Place',
#         'logging_strategy' => 'DataCycleCore::Generic::Logger::Console.new("import")'
#       }
#     }
#   }
# )

module DataCycleCore
  module Generic
    module Xamoom
      class Endpoint
        def initialize(host: nil, end_point: nil, key: nil)
          @host = host
          @end_point = end_point
          @key = key
          @per = 100
        end

        def spots(lang: :de)
          first_page = load_data(0, lang)
          total_items = first_page['meta']['total'].to_i
          max_pages = total_items.fdiv(@per).ceil
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              page = load_data(page - 1, lang)['data'].each do |image_record|
                yielder << image_record
              end
            end
          end
        end

        protected

        def load_data(page = 0, lang = :de)
          response = Faraday.new.get do |req|
            req.url File.join([@host, @end_point])

            req.headers['Accept'] = 'application/json'
            req.headers['Apikey'] = @key
            req.params['lang'] = lang.to_s
            req.params['page[size]'] = @per
            req.params['page[cursor]'] = page
          end

          if response.success?
            JSON.parse(response.body)
          else
            raise DataCycleCore::Generic::RecoverableError, "error loading data from #{File.join([@host, @end_point, @project] + url_path)}"
          end
        end
      end
    end
  end
end
