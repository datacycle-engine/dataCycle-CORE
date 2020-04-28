# frozen_string_literal: true

module DataCycleCore
  module V4
    module ApiHelper
      def assert_api_count_result(count)
        assert_response :success
        assert_equal(response.content_type, 'application/json')
        json_data = JSON.parse(response.body)
        assert_equal(count, json_data['@graph'].size)
        assert_equal(count, json_data['meta']['total'].to_i)
      end
    end
  end
end
