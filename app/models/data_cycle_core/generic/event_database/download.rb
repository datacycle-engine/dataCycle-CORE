module DataCycleCore
  module Generic
    module EventDatabase
      module Download
        def download_content(**options)
          download_data(@source_type, ->(data) { data['url'] }, ->(data) { data['name'] }, options)
        end

        protected

        def endpoint
          @end_point_object.new(credentials.symbolize_keys)
        end
      end
    end
  end
end
