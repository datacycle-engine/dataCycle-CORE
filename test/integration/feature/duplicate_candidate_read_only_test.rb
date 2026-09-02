# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # verifies the read-only merge preview for users that may merge duplicates
    # but have no edit/update permission (granted via user group permission)
    class DuplicateCandidateReadOnlyTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      before(:all) do
        @routes = Engine.routes

        @original = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Original Artikel' })
        @duplicate = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Duplikat Artikel' })

        DataCycleCore.features[:user_group_permission][:enabled] = true
        DataCycleCore::Feature::UserGroupPermission.reload

        # a seeded guest user (no edit/update permission); merge_duplicates is
        # granted below via a user group, mirroring the real-world target user
        @merge_only_user = DataCycleCore::User.find_by(email: 'guest@datacycle.at')

        collection = DataCycleCore::WatchList.create!(
          full_path: "merge_only_collection_#{Time.now.getutc.to_i}",
          thing_ids: [@original.id, @duplicate.id]
        )

        DataCycleCore::UserGroup.create!(
          name: "merge_only_group_#{Time.now.getutc.to_i}",
          user_ids: [@merge_only_user.id],
          permissions: ['test_permission_2'],
          shared_collection_ids: [collection.id]
        )

        @merge_only_user.reload
      end

      after(:all) do
        DataCycleCore.features[:user_group_permission][:enabled] = false
        DataCycleCore::Feature::UserGroupPermission.reload
      end

      setup do
        sign_in(@merge_only_user)
      end

      test 'user may merge duplicates but has no update permission' do
        assert @merge_only_user.can?(:merge_duplicates, @original)
        assert @merge_only_user.cannot?(:update, @original)
      end

      test 'merge view is a read-only preview without the editable form' do
        get merge_with_duplicate_thing_path(@original, @duplicate), params: {}, headers: {
          referer: thing_path(@original)
        }

        assert_response :success
        # editable merge form must not be rendered for a user without update permission
        assert_not_includes response.body, 'edit-content-form'
        # the read-only confirm action must be offered instead
        assert_includes response.body, confirm_merge_with_duplicate_thing_path(@original, duplicate_id: @duplicate.id)
      end

      test 'confirm merge without edit permission merges the duplicate' do
        post confirm_merge_with_duplicate_thing_path(@original, duplicate_id: @duplicate.id), params: {}, headers: {
          referer: merge_with_duplicate_thing_path(@original, @duplicate)
        }

        assert_response :found
        assert_equal I18n.t('controllers.success.merged_with_duplicate', locale: DataCycleCore.ui_locales.first), flash[:success]
        # the duplicate is deleted within the request, not by a background job
        assert_nil DataCycleCore::Thing.find_by(id: @duplicate.id)
        # read-only merge must also write a named version and record who merged, like the editable path
        @original.reload

        assert_predicate @original.version_name, :present?, 'read-only merge should set a named version'
        assert_equal @merge_only_user.id, @original.updated_by, 'read-only merge should record the acting user'
      end

      test 'a read-only merge that fails inline still records the named version' do
        original = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Original mit Fehler' })
        duplicate = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Duplikat mit Fehler' })
        collection = DataCycleCore::WatchList.create!(full_path: "merge_only_failing_#{Time.now.getutc.to_i}", thing_ids: [original.id, duplicate.id])
        @merge_only_user.user_groups.first.shared_collections << collection
        @merge_only_user.reload

        DataCycleCore::Feature::DuplicateCandidate.stub(:merge_duplicate, ->(*) { raise 'inline merge failed' }) do
          DataCycleCore::MergeDuplicateJob.stub(:perform_later, nil) do
            post confirm_merge_with_duplicate_thing_path(original, duplicate_id: duplicate.id), params: {}, headers: {
              referer: merge_with_duplicate_thing_path(original, duplicate)
            }
          end
        end

        assert_equal I18n.t('controllers.error.duplicate.merge_failed', locale: DataCycleCore.ui_locales.first), flash[:error]
        # the version is written before the merge, so a merge failing part way through stays recorded
        original.reload

        assert_predicate original.version_name, :present?, 'a failed merge must still record the named version'
        assert_equal @merge_only_user.id, original.updated_by
      end

      test 'confirm merge is denied for a duplicate outside the permitted collection' do
        outside = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Fremdes Artikel' })

        assert @merge_only_user.cannot?(:merge_duplicates, outside), 'precondition: user must not be allowed to merge content outside their collection'

        post confirm_merge_with_duplicate_thing_path(@original, duplicate_id: outside.id), params: {}, headers: {
          referer: thing_path(@original)
        }

        assert_nil flash[:success], 'merge must not succeed for an unauthorized duplicate'
      end

      test 'merge preview is denied for a duplicate outside the permitted collection' do
        outside = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Fremdes Preview Artikel' })

        get merge_with_duplicate_thing_path(@original, outside), params: {}, headers: {
          referer: thing_path(@original)
        }

        # authorize!(:merge_duplicates, @split_source) must reject an out-of-scope source
        assert_response :redirect
      end

      test 'false positive is denied for a duplicate outside the permitted collection' do
        outside = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Fremdes FP Artikel' })

        post false_positive_duplicate_thing_path(@original, outside), params: {}, headers: {
          referer: thing_path(@original)
        }

        assert_nil flash[:notice], 'false positive must not succeed for an unauthorized duplicate'
      end
    end
  end
end
