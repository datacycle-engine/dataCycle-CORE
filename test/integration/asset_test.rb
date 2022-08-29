# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AssetTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers
    include DataCycleCore::ActiveStorageHelper

    setup do
      @routes = Engine.routes
      sign_in(@current_user = User.find_by(email: 'tester@datacycle.at'))
    end

    test 'return all assets for current user' do
      image = upload_image('test_rgb.jpeg')

      get assets_path, xhr: true, params: {
        html_target: 'search-form',
        selected: '00000000-0000-0000-0000-000000000000',
        types: [
          'DataCycleCore::Image'
        ]
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = JSON.parse response.body
      assert(json_data.dig('assets').any? { |v| v['id'] == image.id })
    end

    test 'create new asset as current user' do
      post assets_path, xhr: true, params: {
        asset: {
          file: fixture_file_upload(File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', 'test_rgb.jpeg')),
          type: 'DataCycleCore::Image'
        }
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = JSON.parse response.body
      assert_equal 'test_rgb.jpeg', json_data['name']
    end

    test 'create invalid asset as current user' do
      post assets_path, xhr: true, params: {
        asset: {
          file: fixture_file_upload(File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', 'test_rgb_invalid.jpeg')),
          type: 'DataCycleCore::Image'
        }
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = JSON.parse response.body
      assert json_data['error'].present?
    end

    test 'update existing asset' do
      image = upload_image('test_rgb.jpeg')
      patch asset_path(image), xhr: true, params: {
        asset: {
          id: image.id,
          file: fixture_file_upload(File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', 'test_rgb_portrait.jpeg'))
        }
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
    end

    test 'update existing asset with invalid asset' do
      image = upload_image('test_rgb.jpeg')

      patch asset_path(image), xhr: true, params: {
        asset: {
          id: image.id,
          file: fixture_file_upload(File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', 'test_rgb_invalid.jpeg'))
        }
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = JSON.parse response.body
      assert json_data['error'].present?
    end

    test 'find existing pdf by name' do
      pdf = upload_text_file('test.pdf')

      get find_assets_path, xhr: true, params: {
        q: 'test.pdf'
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = JSON.parse response.body
      assert_equal pdf.id, json_data['id']
    end

    test 'destroy existing asset' do
      image = upload_image('test_rgb.jpeg')

      delete asset_path(image), xhr: true, params: {}, headers: {
        referer: root_path
      }

      assert_response :success
    end

    test 'duplicate existing asset' do
      image = upload_image('test_rgb.jpeg')

      post duplicate_asset_path(image), xhr: true, params: {}, headers: {
        referer: root_path
      }

      assert_response :success
    end
  end
end
