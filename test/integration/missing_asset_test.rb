# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class MissingAssetTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers
    include DataCycleCore::ActiveStorageHelper

    setup do
      @routes = Engine.routes
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'get asset versions by custom route' do
      file_name = 'test_rgb.jpeg'
      image = upload_image file_name

      get active_storage_url_for(image.thumb_preview), params: {}, headers: {
        referer: root_path
      }
      assert_response :success
      assert_equal 'image/jpeg', response.header['Content-Type']
      assert_equal file_name, response.header['Content-Disposition']&.split(';')&.second&.remove('filename=', '"')&.squish
      get active_storage_url_for(image.file), params: {}, headers: {
        referer: root_path
      }
      assert_response :success
      assert_equal 'image/jpeg', response.header['Content-Type']
      assert_equal file_name, response.header['Content-Disposition']&.split(';')&.second&.remove('filename=', '"')&.squish
    end

    test 'get asset versions in another format' do
      file_name = 'test_rgb.jpeg'
      file_name_png = 'test_rgb.png'
      image = upload_image file_name

      get local_asset_path(klass: 'image', id: image.id, version: 'original'), params: {
        transformation: {
          format: 'png'
        }
      }, headers: {
        referer: root_path
      }
      assert_response :success
      assert_equal 'image/png', response.header['Content-Type']
      assert_equal file_name_png, response.header['Content-Disposition']&.split(';')&.second&.remove('filename=', '"')&.squish

      get local_asset_path(klass: 'image', id: image.id, version: 'thumb_preview'), params: {
        transformation: {
          format: 'png'
        }
      }, headers: {
        referer: root_path
      }
      assert_response :success
      assert_equal 'image/png', response.header['Content-Type']
      assert_equal file_name_png, response.header['Content-Disposition']&.split(';')&.second&.remove('filename=', '"')&.squish
    end

    test 'return 404 for missing files' do
      get File.join(Rails.application.config.asset_host, '/assets/image/4a716959-b68d-4cce-a097-c428db7c9922/not_existing/test_rgbjpeg'), params: {}, headers: {
        referer: root_path
      }

      assert_response :not_found
    end
  end
end
