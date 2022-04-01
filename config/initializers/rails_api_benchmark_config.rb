# frozen_string_literal: true

# # unless Rails.env.production?
# RailsApiBenchmark.configure do |config|
#   config.concurrency = 2
#   config.host = 'web:3000/'
#   config.nb_requests = 20
#   config.results_folder = 'tmp/benchmarks'
#   config.auth_header = ''
#   #Use only if you want to log the responses
#   #config.curl_cmd = 'curl -H "%{auth_header}" http://%{host}%{route}'
#   # Keep plot.tsv to render graph
#   config.bench_cmd = 'ab -n %{nb_requests} -c %{concurrency} -g plot.tsv' \
#    ' -H "%{auth_header}" %{host}%{route}'
#   config.server_cmd = 'ruby -v'
#   config.env_vars = {
#     # 'RAILS_MAX_THREADS' => '2',
#     'SECRET_KEY_BASE' => 'bench',
#     # 'RAILS_ENV' => 'development',
#     # 'PORT' => '3000'
#   }
#   # config.regexps = [
#   #   {
#   #     key: :response_time,
#   #     name: 'Average time per request (ms)',
#   #     regexp: /Time\s+per\s+request:\s+([0-9.]*).*\(mean\)/
#   #   }, {
#   #     key: :req_per_sec,
#   #     name: 'Requests per second (#)',
#   #     regexp: /Requests\s+per\s+second:\s+([0-9.]*).*\(mean\)/
#   #   }
#   # ]
#   config.routes = [
#     {
#       name: 'test APIv2',
#       route: '/api/v2/contents/search?token=63c4fbf71af585250fb5a8c088af3430',
#       # route: '/api/v2/things/11779bd5-c5ec-4f52-ba26-a5c00cffc90e?token=63c4fbf71af585250fb5a8c088af3430\&include=linked',
#       # route: '/api/v2/things/11779bd5-c5ec-4f52-ba26-a5c00cffc90e?token=63c4fbf71af585250fb5a8c088af3430',
#       method: :get,
#       title: 'GET APIv2 Article',
#       description: 'APIv2 Article'
#     },
#     {
#       name: 'test APIv3',
#       route: '/api/v3/contents/search?token=63c4fbf71af585250fb5a8c088af3430',
#       # route: '/api/v3/things/11779bd5-c5ec-4f52-ba26-a5c00cffc90e?token=63c4fbf71af585250fb5a8c088af3430\&include=linked',
#       # route: '/api/v3/things/11779bd5-c5ec-4f52-ba26-a5c00cffc90e?token=63c4fbf71af585250fb5a8c088af3430',
#       method: :get,
#       title: 'GET APIv3 Article',
#       description: 'APIv3 Article'
#     }
#   ].freeze
# end
# #end
