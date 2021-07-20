# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelCps
      class Endpoint
        def initialize(host: nil, end_point: nil, id: nil, **_options)
          @host = host
          @end_point = end_point
          @id = id
        end

        def infrastructure(lang: :de)
          raise "Unsupported Language (#{lang})" unless lang.to_s == 'de'

          Enumerator.new do |yielder|
            (load_data('INFRASTRUKTUR')['INFRA'] || []).each do |infrastructure|
              yielder << infrastructure
            end
          end
        end

        def slopes(lang: :de)
          raise "Unsupported Language (#{lang})" unless lang.to_s == 'de'

          Enumerator.new do |yielder|
            (load_data('PISTEN')['PISTE'] || []).each do |slope|
              yielder << slope
            end
          end
        end

        def lifts(lang: :de)
          raise "Unsupported Language (#{lang})" unless lang.to_s == 'de'

          Enumerator.new do |yielder|
            (load_data('LIFTE')['LIFT'] || []).each do |lift|
              yielder << lift
            end
          end
        end

        class SimpleNoEncoder
          def self.encode(arg)
            "#{arg.keys.first}=#{arg.values.first}"
          end

          def self.decode(arg)
            { arg.split('?').last.split('=').first => arg.split('?').last.split('=').last }
          end
        end

        protected

        def load_data(type)
          connection = Faraday.new(@host + @end_point, request: { params_encoder: SimpleNoEncoder }) do |con|
            con.use FaradayMiddleware::FollowRedirects, limit: 5
            con.adapter Faraday.default_adapter
          end
          response = connection.get do |req|
            req.params['id'] = @id
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / id:#{@id}", response) unless response.success?
          Nokogiri::XML(response.body).xpath("//RESORT/#{type}").first.to_hash
        end
      end
    end
  end
end
