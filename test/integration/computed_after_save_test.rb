# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

module DataCycleCore
  # compute.after_save exists for one user-visible guarantee: the computed value must be stored
  # by the time the request that saved it answers, so the detail view rendered after the
  # save-redirect already shows it. With compute.async the same value only appears on a later
  # page load (UpdateAsyncComputedPropertiesJob sits in the cache_invalidation queue behind a
  # 60s worker poll, and nothing pushes the update to the open page). This test drives the real
  # editor path to pin that guarantee down.
  class ComputedAfterSaveTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @tags = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 2', 'Tag 3', 'Nested Tag 1').index_by(&:name)
      @content = DataCycleCore::TestPreparations.create_content(
        template_name: 'PrimaryIcon-Place',
        data_hash: { name: 'AfterSaveComputedPlace' }
      )
    end

    setup do
      @current_user = User.find_by(email: 'admin@datacycle.at')
      sign_in(@current_user)
    end

    # icons exist on Tag 2 and Tag 3 (parent of "Nested Tag 1"), not on "Nested Tag 1" itself
    def with_icons(&)
      DataCycleCore.stub(
        :classification_icons,
        { @tags['Tag 2'].id => 'tag2.svg', @tags['Tag 3'].id => 'tag3.svg' },
        &
      )
    end

    def update_classifications(classification_ids)
      patch thing_path(@content), params: {
        locale: 'de',
        thing: { datahash: { universal_classifications: classification_ids } }
      }, headers: { referer: thing_path(@content) }
    end

    def stored_icon_ids
      Array.wrap(DataCycleCore::Thing.find(@content.id).get_data_hash['primary_icon_classifications'])
    end

    test 'the computed icon is stored before the update request answers' do
      with_icons do
        update_classifications([@tags['Tag 2'].classification_id])

        assert_response :redirect
        assert_equal(
          [@tags['Tag 2'].classification_id],
          stored_icon_ids,
          'the icon must be persisted when the redirect is issued, not by a later job'
        )
      end
    end

    test 'the detail view rendered after the save-redirect already has the icon' do
      with_icons do
        # assigned to the icon-less "Nested Tag 1" so the stored icon ("Tag 3") is a concept the
        # content is not directly classified with — its presence can only come from the compute
        update_classifications([@tags['Nested Tag 1'].classification_id])

        assert_equal([@tags['Tag 3'].classification_id], stored_icon_ids)

        follow_redirect!

        assert_response :success
        assert_includes response.body, @tags['Tag 3'].internal_name
      end
    end

    test 'the update request does not defer the compute to a background job' do
      with_icons do
        DataCycleCore::UpdateAsyncComputedPropertiesJob.stub(:perform_later, ->(*) { flunk('compute.after_save must be handled inside the request') }) do
          update_classifications([@tags['Tag 2'].classification_id])
        end

        assert_equal([@tags['Tag 2'].classification_id], stored_icon_ids)
      end
    end

    test 'an icon-neutral classification change still reports success to the editor' do
      with_icons do
        update_classifications([@tags['Tag 2'].classification_id])
        follow_redirect!

        # adding an icon-less concept stores the edit but leaves the icon alone: the recompute's
        # internal no_changes must not turn the editor's confirmation into "nothing happened"
        update_classifications([@tags['Tag 2'].classification_id, @tags['Nested Tag 1'].classification_id])

        assert_response :redirect
        assert_nil(flash[:info], "the recompute's no_changes must not reach the editor")
        assert_equal(
          I18n.t('controllers.success.updated', data: 'PrimaryIcon-Place', locale: :de),
          flash[:success],
          'the save confirmation must not be swallowed'
        )
        assert_equal([@tags['Tag 2'].classification_id], stored_icon_ids)
      end
    end

    test 'the computed icon cannot be forced through request params' do
      with_icons do
        update_classifications([@tags['Tag 2'].classification_id])

        assert_equal([@tags['Tag 2'].classification_id], stored_icon_ids)

        # computed properties are stripped in DataHashService#permit_param_for_prop, so a crafted
        # request cannot plant an icon the compute would not have produced
        patch thing_path(@content), params: {
          locale: 'de',
          thing: { datahash: { primary_icon_classifications: [@tags['Nested Tag 1'].classification_id] } }
        }, headers: { referer: thing_path(@content) }

        assert_equal([@tags['Tag 2'].classification_id], stored_icon_ids, 'a computed property must not be writable from params')
      end
    end

    test 'a failing recompute rolls the whole editor save back' do
      with_icons do
        update_classifications([@tags['Tag 2'].classification_id])

        assert_equal([@tags['Tag 2'].classification_id], stored_icon_ids)

        # the template's only compute is the after_save one, so this hits exactly that pass
        DataCycleCore::Utility::Compute::Base.stub(:compute_values, ->(*) { raise 'compute exploded' }) do
          assert_raises(RuntimeError) { update_classifications([@tags['Nested Tag 1'].classification_id]) }
        end

        reloaded = DataCycleCore::Thing.find(@content.id)

        assert_equal(
          [@tags['Tag 2'].classification_id],
          Array.wrap(reloaded.get_data_hash['universal_classifications']),
          'the edit must not be stored when its computed value could not be calculated'
        )
        assert_equal([@tags['Tag 2'].classification_id], Array.wrap(reloaded.get_data_hash['primary_icon_classifications']))
      end
    end

    test 'clearing the classifications clears the stored icon within the same request' do
      with_icons do
        update_classifications([@tags['Tag 2'].classification_id])

        assert_equal([@tags['Tag 2'].classification_id], stored_icon_ids)

        update_classifications([])

        assert_empty stored_icon_ids
      end
    end
  end
end
