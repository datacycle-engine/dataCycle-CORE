# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Mvt
    module V1
      # The MVT endpoints answer `bbox` requests with a JSON body even though the
      # route format is `:pbf`. That mismatch is the precondition for the
      # intermittent RespondToMismatchError fixed in DataCycleCore::ErrorHandler
      # and DataCycleCore::User#log_request_activity, so make sure the happy path
      # actually renders JSON and is logged without raising.
      class ContentsTest < DataCycleCore::V4::Base
        before(:all) do
          @poi = DataCycleCore::DummyDataHelper.create_data('poi')
          @poi.set_data_hash(
            partial_update: true,
            prevent_history: true,
            data_hash: { location: RGeo::Geographic.spherical_factory(srid: 4326).point(11.4, 47.26) }
          )
        end

        test 'bbox select renders a JSON body and is logged on a pbf route' do
          assert_difference -> { DataCycleCore::Activity.where(activity_type: 'mvt_v1').count }, 1 do
            post mvt_v1_contents_select_bbox_path(uuids: @poi.id)
          end

          assert_response(:success)
          assert_equal('application/json; charset=utf-8', response.content_type)

          bbox = response.parsed_body

          assert_kind_of(Hash, bbox)
          assert(['xmin', 'ymin', 'xmax', 'ymax'].all? { |key| bbox.key?(key) }, "expected a bbox hash, got: #{bbox.inspect}")
        end
      end
    end
  end
end
