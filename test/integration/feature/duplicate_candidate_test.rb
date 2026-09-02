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
        @content = create_content('Artikel', { name: 'TestArtikel' })
        image1 = upload_image('test_rgb.jpeg')

        assert_predicate image1.thumb_preview, :present?
        @content1 = create_content('Bild', { name: 'Test Bild 1', asset: image1.id })

        image2 = upload_image('test_rgb.png')

        assert_predicate image2.thumb_preview, :present?

        @content2 = create_content('Bild', { name: 'Test Bild 2', asset: image2.id })
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
        original, duplicate = merge_pair

        patch thing_path(original), params: merge_params(original, duplicate), headers: { referer: merge_with_duplicate_thing_path(original, @content) }

        assert_response :found
        assert_equal I18n.t('controllers.success.merged_with_duplicate', locale: DataCycleCore.ui_locales.first), flash[:success]
        # the duplicate is deleted within the request, not by a background job
        assert_nil DataCycleCore::Thing.find_by(id: duplicate.id)
        assert_predicate original.thing_history_links.reload, :present?
      end

      test 'merge over the inline limit is handed to the background job' do
        original, duplicate = merge_pair
        enqueued = []

        DataCycleCore::Feature::DuplicateCandidate.stub(:merge_inline?, false) do
          DataCycleCore::MergeDuplicateJob.stub(:perform_later, ->(*args) { enqueued << args }) do
            patch thing_path(original), params: merge_params(original, duplicate), headers: { referer: merge_with_duplicate_thing_path(original, @content) }
          end
        end

        assert_response :found
        assert_equal [[original.id, duplicate.id, tester.id]], enqueued
        assert_equal I18n.t('controllers.success.merged_with_duplicate_background', locale: DataCycleCore.ui_locales.first), flash[:success]
        assert_predicate DataCycleCore::Thing.find_by(id: duplicate.id), :present?
      end

      test 'a failed inline merge is reported as an error and handed to the background job' do
        original, duplicate = merge_pair
        enqueued = []
        failures = []
        subscriber = ActiveSupport::Notifications.subscribe('duplicate_merge_failed.datacycle') { |*, payload| failures << payload }

        DataCycleCore::Feature::DuplicateCandidate.stub(:merge_duplicate, ->(*) { raise 'inline merge failed' }) do
          DataCycleCore::MergeDuplicateJob.stub(:perform_later, ->(*args) { enqueued << args }) do
            patch thing_path(original), params: merge_params(original, duplicate), headers: { referer: merge_with_duplicate_thing_path(original, @content) }
          end
        end

        assert_response :found
        assert_equal [[original.id, duplicate.id, tester.id]], enqueued
        assert_equal I18n.t('controllers.error.duplicate.merge_failed', locale: DataCycleCore.ui_locales.first), flash[:error]
        # the error is the only verdict: ContentsController#update reported the preceding save as
        # a success, that message must be gone so the failed merge is not read as a working one
        assert_nil flash[:success]
        # flash messages end up in an innerHTML sink => the exception must not be rendered into markup
        assert_not_includes flash[:error], '<'
        reported_messages = failures.map { |payload| payload[:exception].message }

        assert_equal ['inline merge failed'], reported_messages
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      private

      def tester
        User.find_by(email: 'tester@datacycle.at')
      end

      # merging destroys the duplicate, so every merge test needs a pair of its own
      def merge_pair
        [
          DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Merge Ziel' }),
          DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Merge Duplikat' })
        ]
      end

      def merge_params(original, duplicate)
        {
          duplicate_id: duplicate.id,
          uuid: original.id,
          table: 'things',
          locale: I18n.locale,
          thing: {
            datahash: {
              creator: original.created_by,
              name: original.name
            }
          }
        }
      end
    end
  end
end
