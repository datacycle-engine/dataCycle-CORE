# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Sort
        class TypeTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            @routes = Engine.routes

            @content_a = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            @content_b = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment')
            @content_c = DataCycleCore::V4::DummyDataHelper.create_data('image')
            @content_d = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'api/v4/things with parameter sort: @type' do
            # default no sorting
            expected = [@content_a.template_name, @content_b.template_name, @content_c.template_name, @content_d.template_name].map { |t| "dcls:#{t}" }
            params = {
              sort: "@type(#{expected.join(',')})"
            }
            post api_v4_things_path(params)

            json_data = response.parsed_body

            assert_equal(expected, json_data['@graph'].map { |item| item['@type'].last }.uniq)
          end

          test 'api/v4/things with parameter sort: @type and minimal result' do
            # default no sorting
            expected = [@content_a.template_name, @content_b.template_name, @content_c.template_name, @content_d.template_name].map { |t| "dcls:#{t}" }
            params = {
              sort: "@type(#{expected.join(',')})",
              fields: '@type'
            }
            post api_v4_things_path(params)

            json_data = response.parsed_body

            assert_equal(expected, json_data['@graph'].map { |item| item['@type'].last }.uniq)
          end
        end
      end
    end
  end
end
