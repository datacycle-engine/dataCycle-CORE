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

    test 'processed route serves files under public/uploads (happy path)' do
      file_name = 'processed_test.txt'
      image = upload_image 'test_rgb.jpeg'

      content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'ProcessedThing', asset: image.id })
      dir = Rails.public_path.join('uploads', 'processed', 'image', content.id)
      FileUtils.mkdir_p(dir)
      file_path = dir.join(file_name)
      File.write(file_path, 'processed-ok')

      get "/processed/image/#{content.id}/#{file_name}", params: {}, headers: { referer: root_path }

      assert_response :success
      assert_equal 'processed-ok', response.body
    ensure
      File.delete(file_path) if file_path && File.exist?(file_path)
    end

    test 'blocks path traversal attempts on processed route' do
      id = '18e8e9e4-eb3f-4348-93ec-f81e500c89dc'
      file_name = '%2e%2e/%2e%2e/%2e%2e/%2e%2e/robots.txt'

      get "/processed/image/#{id}/#{file_name}", params: {}, headers: { referer: root_path }

      assert_response :not_found
      assert_equal '', response.body

      file_name = '%252e%252e/%252e%252e/%252e%252e/%252e%252e/robots.txt'

      get "/processed/image/#{id}/#{file_name}", params: {}, headers: { referer: root_path }

      assert_response :not_found
      assert_equal '', response.body
    end

    test 'valid asset paths should be served correctly when single dot is encoded' do
      file_name = 'test_rgb.jpeg'
      image = upload_image file_name

      url = active_storage_url_for(image.thumb_preview)
      encoded_url = url.gsub('.', '%2e')

      get encoded_url, params: {}, headers: {
        referer: root_path
      }

      assert_response :success
    end
  end
end
