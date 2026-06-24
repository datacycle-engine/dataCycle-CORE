# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class DuplicateCandidateTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      before(:all) do
        updates = []
        bild_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Bild')
        updates << { template_name: bild_template.template_name, schema: bild_template.schema.deep_merge('features' => { 'duplicate_candidate' => { 'allowed' => true, 'module' => 'BildPhash' } }) }
        DataCycleCore::ThingTemplate.upsert_all(updates, unique_by: :template_name)

        @routes = Engine.routes
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
        image1 = upload_image('test_rgb.jpeg')

        assert_predicate image1.thumb_preview, :present?
        @content1 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: image1.id })

        image2 = upload_image('test_rgb.png')

        assert_predicate image2.thumb_preview, :present?

        @content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2', asset: image2.id })
      end

      setup do
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      test 'show merge view for duplicates of same type' do
        get merge_with_duplicate_thing_path(@content1, @content2), params: {}, headers: {
          referer: thing_path(@content1)
        }

        assert_response :success

        get merge_with_duplicate_thing_path(@content1, @content), params: {}, headers: {
          referer: thing_path(@content1)
        }

        assert_response :found
        assert_equal I18n.t('controllers.error.duplicate.type_mismatch', locale: DataCycleCore.ui_locales.first), flash[:alert]
      end

      test 'mark duplicate as false positive' do
        assert_equal 1, @content1.duplicate_candidates.reload.size
        assert_equal 1, @content2.duplicate_candidates.reload.size

        post false_positive_duplicate_thing_path(@content1, @content2), params: {}, headers: {
          referer: thing_path(@content1)
        }

        assert_response :found
        assert_equal I18n.t('controllers.success.duplicate_false_positive', locale: DataCycleCore.ui_locales.first, data: @content2.try(:title)), flash[:notice]
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

        assert_response :found
        assert_equal I18n.t('controllers.success.merged_with_duplicate', locale: DataCycleCore.ui_locales.first), flash[:success]
      end
    end
  end
end
