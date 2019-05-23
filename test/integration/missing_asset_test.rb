# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class MissingAssetTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      sign_in(User.find_by(email: 'tester@datacycle.at'))
      DataCycleCore::ImageUploader.enable_processing = true
    end

    teardown do
      DataCycleCore::ImageUploader.enable_processing = false
    end

    def upload_image(file_name)
      file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
      @image = DataCycleCore::Image.new(file: File.open(file_path))
      @image.save

      assert(@image.persisted?)
      assert(@image.valid?)

      @image.reload
    end

    test 'get asset versions by custom route' do
      file_name = 'test_rgb.jpg'
      image = upload_image file_name

      get image.thumb_preview.url, params: {}, headers: {
        referer: root_path
      }
      assert_response :success
      assert_equal 'image/jpeg', response.header['Content-Type']

      get image.file.url, params: {}, headers: {
        referer: root_path
      }
      assert_response :success
      assert_equal 'image/jpeg', response.header['Content-Type']
    end

    test 'return 404 for missing files' do
      assert_raises(ActiveRecord::RecordNotFound) do
        get File.join(Rails.application.config.asset_host, '/assets/image/4a716959-b68d-4cce-a097-c428db7c9922/not_existing/test_rgb.jpg'), params: {}, headers: {
          referer: root_path
        }
      end
    end
  end
end
