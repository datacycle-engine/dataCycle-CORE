# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      class Endpoint
        def initialize(host: nil, end_point: nil, **options)
          @host = host
          @end_point = end_point
          @user = options[:user]
          @token = options[:token]
          @per = 100
        end

        def ratings(lang:)
          total = load_facility_count.dig('data', 'facilities_count').to_i
          pages = total.fdiv(@per).ceil
          Enumerator.new do |yielder|
            (1..pages).each do |page|
              load_facilities(page, lang)&.dig('data', 'facilities')&.each do |event|
                yielder << event
              end
            end
          end
        end

        protected

        def load_facilities(page, lang)
          query = <<-EOS
            {
              facilities(limit: #{@per}, offset: #{(page - 1) * @per}) {
                uuid
                base_data {
                  name_#{lang}
                }
                public_pdf {
                  url_for_short_report { #{lang} }
                  url_for_allergic { #{lang} }
                  url_for_deaf { #{lang} }
                  url_for_generations { #{lang} }
                  url_for_mental { #{lang} }
                  url_for_visual { #{lang} }
                  url_for_walking { #{lang} }
                  url_for_wheelchair { #{lang} }
                }
                short_report {
                  deaf_and_partially_deaf_#{lang}
                  mental_#{lang}
                  visual_and_partially_visual_#{lang}
                  wheelchair_and_walking_#{lang}
                }
                certificate_data {
                  certified_from
                  certified_to
                  certificate_type {
                    icon_url_#{lang}
                    key
                    label_#{lang}
                  }
                  deaf {
                    icon_url
                    level
                  }
                  mental {
                    icon_url
                    level
                  }
                  partially_deaf {
                    icon_url
                    level
                  }
                  partially_visual {
                    icon_url
                    level
                  }
                  visual {
                    icon_url
                    level
                  }
                  walking {
                    icon_url
                    level
                  }
                  wheelchair {
                    icon_url
                    level
                  }
                }
             		third_party_ids {
            		  key
            		  value
            		}
                licence_owner
                sections_count
                grouped_search_criteria {
                  guest_group {
                    key
                    name_#{lang}
                  }
                  search_criteria {
                    id
                    name_#{lang}
                  }
                }
              }
            }
          EOS
          load_data(query)
        end

        def load_facility_count
          query = <<-EOS
            {
              facilities_count
            }
          EOS
          load_data(query)
        end

        def load_data(query)
          url = [@host, @end_point].join('/')
          conn = Faraday.new(url: url) do |connection|
            connection.request(:basic_auth, @user, @token)
          end
          response = conn.post do |req|
            req.headers['Content-Type'] = 'application/json'
            req.body = { 'query' => query }.to_json
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
