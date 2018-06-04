# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GooglePlaces
      module DownloadDetail
        def download_content(**options)
          @read_type = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: options[:download][:read_type])
          download_data(->(data) { data['place_id'] }, ->(data) { data['name'] }, options)
        end

        protected

        def endpoint
          end_point_object.new(credentials.symbolize_keys.merge(read_type: @read_type))
        end
      end
    end
  end
end
