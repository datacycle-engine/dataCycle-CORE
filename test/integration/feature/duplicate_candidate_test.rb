# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class DuplicateCandidateTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      before(:all) do
        @routes = Engine.routes
        DataCycleCore::ImageUploader.enable_processing = true
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
        image1 = upload_image 'test_rgb.jpg'
        @content1 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image1.id })

        image2 = upload_image 'test_rgb.png'
        @content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2', asset: image2.id })
      end

      after(:all) do
        DataCycleCore::ImageUploader.enable_processing = false
      end

      setup do
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      def upload_image(file_name)
        file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
        image = DataCycleCore::Image.new(file: File.open(file_path))
        image.save
        image
      end

      test 'show merge view for duplicates of same type' do
        get merge_with_duplicate_thing_path(@content1, @content2), params: {}, headers: {
          referer: thing_path(@content1)
        }

        assert_response :success

        get merge_with_duplicate_thing_path(@content1, @content), params: {}, headers: {
          referer: thing_path(@content1)
        }

        assert_response 302
        assert_equal I18n.t(:type_mismatch, scope: [:controllers, :error, :duplicate], locale: DataCycleCore.ui_locales.first), flash[:alert]
      end

      test 'mark duplicate as false positive' do
        assert_empty @content1.duplicate_candidates
        assert_empty @content2.duplicate_candidates

        DataCycleCore::Thing
          .where(template: false, external_source_id: nil, external_key: nil, template_name: 'Bild')
          .where.not(content_type: 'embedded')
          .find_each(&:create_duplicate_candidates)

        assert_equal 1, @content1.duplicate_candidates.reload.size
        assert_equal 1, @content2.duplicate_candidates.reload.size

        post false_positive_duplicate_thing_path(@content1, @content2), params: {}, headers: {
          referer: thing_path(@content1)
        }

        assert_response 302
        assert_equal I18n.t(:duplicate_false_positive, scope: [:controllers, :success], locale: DataCycleCore.ui_locales.first, data: @content2.try(:title)), flash[:notice]
      end

      test 'merge duplicate with original' do
        patch thing_path(@content1), params: {
          duplicate_id: @content2.id,
          uuid: @content1.id,
          table: 'things',
          locale: I18n.locale,
          thing: {
            datahash: {
              creator: @content1.created_by,
              name: @content1.name,
              asset: @content1.asset.id
            }
          }
        }, headers: {
          referer: merge_with_duplicate_thing_path(@content1, @content)
        }

        assert_response 302
        assert_equal I18n.t(:merged_with_duplicate, scope: [:controllers, :success], locale: DataCycleCore.ui_locales.first), flash[:success]
      end
    end
  end
end
