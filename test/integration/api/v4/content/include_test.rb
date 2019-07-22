# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class IncludeTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @content_tour = DataCycleCore::DummyDataHelper.create_data('tour')
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'tour at /api/v4/things/:id serializes without included embedded/linked data' do
          get api_v4_thing_path(id: @content_tour.id)
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          # full header of main item
          header = json_data.slice(*full_header_attributes)
          content_data = full_header_data(@content_tour)
          assert_equal(header, content_data)

          # all embedded/linked have a compact header
          (@content_tour.embedded_property_names + @content_tour.linked_property_names - ['overlay']).each do |embedded|
            assert_compact_header(json_data.dig(embedded.camelize(:lower)))
          end
        end

        test 'tour with included embedded schedule' do
          get api_v4_thing_path(id: @content_tour.id, include: 'schedule')
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          # full header of main item
          header = json_data.slice(*full_header_attributes)
          content_data = full_header_data(@content_tour)
          assert_equal(header, content_data)

          # all embedded/linked have at least a compact header
          (@content_tour.embedded_property_names + @content_tour.linked_property_names - ['overlay', 'schedule']).each do |embedded|
            assert_compact_header(json_data.dig(embedded.camelize(:lower)))
          end

          # schedule has a full header
          header_schedule = json_data.dig('schedule', 0).slice(*full_header_attributes)
          data_schedule = full_header_data(@content_tour.schedule.first)
          assert_equal(header_schedule, data_schedule.except('inLanguage'))
        end

        test 'tour with included linked poi' do
          get api_v4_thing_path(id: @content_tour.id, include: 'poi')
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          # full header of main item
          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@content_tour)
          assert_equal(header, data)

          # all embedded/linked have a compact header
          (@content_tour.embedded_property_names + @content_tour.linked_property_names - ['overlay', 'poi']).each do |embedded|
            assert_compact_header(json_data.dig(embedded.camelize(:lower)))
          end

          # poi has a full header
          header = json_data.dig('poi', 0).slice(*full_header_attributes)
          data = full_header_data(@content_tour.poi.first)
          assert_equal(header, data)
        end

        test 'tour with included linked poi,poi.image' do
          get api_v4_thing_path(id: @content_tour.id, include: 'poi,poi.image')
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          # full header of main item
          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@content_tour)
          assert_equal(header, data)

          # all embedded/linked have a compact header
          (@content_tour.embedded_property_names + @content_tour.linked_property_names - ['overlay', 'poi']).each do |embedded|
            assert_compact_header(json_data.dig(embedded.camelize(:lower)))
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

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          # full header of main item
          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@content_tour)
          assert_equal(header, data)

          # all embedded/linked have a compact header
          (@content_tour.embedded_property_names + @content_tour.linked_property_names - ['overlay', 'poi', 'image']).each do |embedded|
            assert_compact_header(json_data.dig(embedded.camelize(:lower)))
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
