# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module Content
        class IncludeTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          include DataCycleCore::ApiV4Helper

          before(:all) do
            DataCycleCore::Thing.delete_all
            @routes = Engine.routes
            @content_tour = DataCycleCore::DummyDataHelper.create_data('tour')
          end

          def excluded_attributes
            @excluded_attributes ||= [
              'overlay',
              'subject_of',
              'is_linked_to',
              'linked_thing',
              'potential_action',
              'opening_hours_specification',
              'contains_place',
              'contained_in_place',
              'poi',
              'image',
              'opening_hours_description',
              'schedule',
              'sd_publisher',
              'external_content_score'
            ]
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'tour at /api/v4/things/:id serializes without included embedded/linked data' do
            get api_v4_thing_path(id: @content_tour.id)
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            # full header of main item
            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content_tour)
            assert_equal(header, data)
            # all embedded/linked have a compact header
            (@content_tour.embedded_property_names + @content_tour.linked_property_names - excluded_attributes).each do |embedded|
              next if @content_tour.properties_for(embedded)&.dig('api', 'v4', 'disabled').to_s == 'true'
              next if @content_tour.properties_for(embedded)&.dig('api', 'disabled').to_s == 'true'

              json_key = @content_tour.schema.dig('properties', embedded, 'api', 'v4', 'name') || @content_tour.schema.dig('properties', embedded, 'api', 'name') || embedded.camelize(:lower)
              assert_compact_header(json_data[json_key])
            end
          end

          test 'tour with included embedded schedule' do
            get api_v4_thing_path(id: @content_tour.id, include: 'schedule')
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            # full header of main item
            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content_tour)
            assert_equal(header, data)

            # all embedded/linked have at least a compact header
            (@content_tour.embedded_property_names + @content_tour.linked_property_names - excluded_attributes).each do |embedded|
              next if @content_tour.properties_for(embedded)&.dig('api', 'v4', 'disabled').to_s == 'true'
              next if @content_tour.properties_for(embedded)&.dig('api', 'disabled').to_s == 'true'

              json_key = @content_tour.schema.dig('properties', embedded, 'api', 'v4', 'name') || @content_tour.schema.dig('properties', embedded, 'api', 'name') || embedded.camelize(:lower)
              assert_compact_header(json_data[json_key])
            end

            # schedule has a full header
            # !!! the following assertions are not valid any more because the schedule definition has changed significantly
            # header_schedule = json_data.dig('schedule', 0).slice(*full_header_attributes)
            # data_schedule = full_header_data(@content_tour.schedule.first).except('name')
            # assert_equal(header_schedule, data_schedule)
          end

          test 'tour with included linked poi' do
            get api_v4_thing_path(id: @content_tour.id, include: 'poi')
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            # full header of main item
            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content_tour)
            assert_equal(header, data)

            # all embedded/linked have a compact header
            (@content_tour.embedded_property_names + @content_tour.linked_property_names - excluded_attributes).each do |embedded|
              next if @content_tour.properties_for(embedded)&.dig('api', 'v4', 'disabled').to_s == 'true'
              next if @content_tour.properties_for(embedded)&.dig('api', 'disabled').to_s == 'true'

              json_key = @content_tour.schema.dig('properties', embedded, 'api', 'v4', 'name') || @content_tour.schema.dig('properties', embedded, 'api', 'name') || embedded.camelize(:lower)
              assert_compact_header(json_data[json_key])
            end

            # poi has a full header
            header = json_data.dig('poi', 0).slice(*full_header_attributes)
            data = full_header_data(@content_tour.poi.first)
            assert_equal(header, data)
          end

          test 'tour with included linked poi,poi.image' do
            get api_v4_thing_path(id: @content_tour.id, include: 'poi,poi.image')
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            # full header of main item
            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content_tour)
            assert_equal(header, data)

            # all embedded/linked have a compact header
            (@content_tour.embedded_property_names + @content_tour.linked_property_names - excluded_attributes).each do |embedded|
              next if @content_tour.properties_for(embedded)&.dig('api', 'v4', 'disabled').to_s == 'true'
              next if @content_tour.properties_for(embedded)&.dig('api', 'disabled').to_s == 'true'

              json_key = @content_tour.schema.dig('properties', embedded, 'api', 'v4', 'name') || @content_tour.schema.dig('properties', embedded, 'api', 'name') || embedded.camelize(:lower)
              assert_compact_header(json_data[json_key])
            end

            # poi has a full header
            header = json_data.dig('poi', 0).slice(*full_header_attributes)
            data = full_header_data(@content_tour.poi.first)
            assert_equal(header, data)

            # poi.image has a full header
            header = json_data.dig('poi', 0, 'image', 0).slice(*full_header_attributes) # primary_image renamed to image
            data = full_header_data(@content_tour.poi.first.primary_image.first)
            assert_equal(header, data)
          end

          test 'tour with multiple includes' do
            get api_v4_thing_path(id: @content_tour.id, include: 'poi,poi.image,image')
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            # full header of main item
            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content_tour)
            assert_equal(header, data)

            # all embedded/linked have a compact header
            (@content_tour.embedded_property_names + @content_tour.linked_property_names - excluded_attributes).each do |embedded|
              next if @content_tour.properties_for(embedded)&.dig('api', 'v4', 'disabled').to_s == 'true'
              next if @content_tour.properties_for(embedded)&.dig('api', 'disabled').to_s == 'true'

              json_key = @content_tour.schema.dig('properties', embedded, 'api', 'v4', 'name') || @content_tour.schema.dig('properties', embedded, 'api', 'name') || embedded.camelize(:lower)
              assert_compact_header(json_data[json_key])
            end

            # poi has a full header
            header = json_data.dig('poi', 0).slice(*full_header_attributes)
            data = full_header_data(@content_tour.poi.first)
            assert_equal(header, data)

            # image has a full header
            header = json_data.dig('image', 0).slice(*full_header_attributes)
            data = full_header_data(@content_tour.image.first)
            assert_equal(header, data)

            # poi.image has a full header
            header = json_data.dig('poi', 0, 'image', 0).slice(*full_header_attributes) # primary_image renamed to image
            data = full_header_data(@content_tour.poi.first.primary_image.first)
            assert_equal(header, data)
          end
        end
      end
    end
  end
end
