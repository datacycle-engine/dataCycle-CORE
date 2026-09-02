# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

module DataCycleCore
  module Content
    module Attributes
      class ComputedPrimaryIconTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @tags = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 1', 'Tag 2', 'Tag 3', 'Nested Tag 1').index_by(&:name)
          @markets = DataCycleCore::Concept.for_tree('Märkte').with_name('Markt 1', 'Markt 2').index_by(&:name)
        end

        # icons exist on Tag 2, Tag 3 (parent of "Nested Tag 1") and Markt 2 —
        # NOT on Tag 1, "Nested Tag 1" or Markt 1
        def with_icons(&)
          DataCycleCore.stub(
            :classification_icons,
            {
              @tags['Tag 2'].id => 'tag2.svg',
              @tags['Tag 3'].id => 'tag3.svg',
              @markets['Markt 2'].id => 'markt2.svg'
            },
            &
          )
        end

        def create_content(data_hash)
          DataCycleCore::TestPreparations.create_content(template_name: 'PrimaryIcon-Place', data_hash: data_hash.merge('name' => 'Primary Icon Test'))
        end

        # the attribute is computed with compute.after_save, i.e. synchronously right after the
        # save that triggered it — so it is already stored when set_data_hash returns and no
        # recompute has to be simulated here
        def primary_icon_ids(content)
          Array.wrap(content.reload.get_data_hash['primary_icon_classifications'])
        end

        test 'override wins over the assigned classifications' do
          with_icons do
            content = create_content(
              'universal_classifications' => [@tags['Tag 2'].classification_id],
              'primary_icon_tags' => [@tags['Tag 3'].classification_id]
            )

            assert_equal([@tags['Tag 3'].classification_id], primary_icon_ids(content))
          end
        end

        test 'override on a child concept resolves to the nearest ancestor with an icon' do
          with_icons do
            # "Nested Tag 1" has no icon, its parent "Tag 3" does
            content = create_content('primary_icon_tags' => [@tags['Nested Tag 1'].classification_id])

            assert_equal([@tags['Tag 3'].classification_id], primary_icon_ids(content))
          end
        end

        test 'override without any icon in its ancestry yields no primary icon' do
          with_icons do
            content = create_content('primary_icon_tags' => [@tags['Tag 1'].classification_id])

            assert_empty(primary_icon_ids(content))
          end
        end

        test 'without override the first assigned classification with icon wins (tree order)' do
          with_icons do
            content = create_content(
              'universal_classifications' => [@tags['Tag 3'].classification_id, @tags['Tag 2'].classification_id, @markets['Markt 1'].classification_id]
            )

            # Tag 2 comes before Tag 3 in tree order, Markt 1 has no icon
            assert_equal([@tags['Tag 2'].classification_id], primary_icon_ids(content))
          end
        end

        test 'fallback resolves an assigned leaf concept to its icon-bearing ancestor' do
          with_icons do
            # assigned only to the icon-less child "Nested Tag 1" => its parent "Tag 3" wins
            content = create_content('universal_classifications' => [@tags['Nested Tag 1'].classification_id])

            assert_equal([@tags['Tag 3'].classification_id], primary_icon_ids(content))
          end
        end

        test 'override and fallback merge across both trees' do
          with_icons do
            content = create_content(
              'primary_icon_tags' => [@tags['Tag 2'].classification_id],
              'universal_classifications' => [@markets['Markt 2'].classification_id]
            )

            assert_equal(
              Set[@tags['Tag 2'].classification_id, @markets['Markt 2'].classification_id],
              primary_icon_ids(content).to_set
            )
          end
        end

        test 'removing override and classifications clears the computed value' do
          with_icons do
            content = create_content('primary_icon_tags' => [@tags['Tag 2'].classification_id])

            assert_equal([@tags['Tag 2'].classification_id], primary_icon_ids(content))

            content.set_data_hash(data_hash: { 'primary_icon_tags' => [], 'universal_classifications' => [] })

            assert_empty(primary_icon_ids(content))
          end
        end

        test 'within a tree the first non-blank override wins (parameter order = priority)' do
          with_icons do
            # both overrides set on the same tree => the first parameter (primary_icon_tags) wins
            content = create_content(
              'primary_icon_tags' => [@tags['Tag 2'].classification_id],
              'primary_icon_tags_secondary' => [@tags['Tag 3'].classification_id]
            )

            assert_equal([@tags['Tag 2'].classification_id], primary_icon_ids(content))
          end
        end

        test 'within a tree the secondary override is used when the first is blank' do
          with_icons do
            content = create_content('primary_icon_tags_secondary' => [@tags['Tag 3'].classification_id])

            assert_equal([@tags['Tag 3'].classification_id], primary_icon_ids(content))
          end
        end

        test 'a hidden mapping does not drive the primary icon (#47172/#47053/#50677)' do
          with_icons do
            # a source concept mapped onto icon-bearing "Tag 2" in a tree that hides its mappings: the
            # only path to an icon is through that mapping, so the icon must stay empty.
            source_tree = DataCycleCore::ClassificationTreeLabel.create!(name: "IconSrc_#{SecureRandom.hex(6)}")
            source_alias = source_tree.create_classification_alias('MappedSource')
            DataCycleCore::ClassificationGroup.create!(classification: source_alias.primary_classification, classification_alias: @tags['Tag 2'].classification_alias)
            tags_tree = @tags['Tag 2'].classification_alias.classification_tree_label
            tags_tree.update!(hidden_mappings: true)

            content = create_content('universal_classifications' => [source_alias.primary_classification.id])

            assert_empty(primary_icon_ids(content), 'a hidden mapping must not classify the content for the icon')
          ensure
            tags_tree&.update!(hidden_mappings: false)
          end
        end

        test 'changing classifications through the save path recomputes the value' do
          with_icons do
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

            assert_equal([@tags['Tag 2'].classification_id], primary_icon_ids(content))

            content.set_data_hash(data_hash: { 'universal_classifications' => [@tags['Tag 3'].classification_id] })

            assert_equal([@tags['Tag 3'].classification_id], primary_icon_ids(content), 'Tag 2 was removed, so it must not resurrect from stale relations')
          end
        end

        # ---------- compute.after_save mode ----------

        test 'the value is computed by the save itself, never handed to a background job' do
          with_icons do
            DataCycleCore::UpdateAsyncComputedPropertiesJob.stub(:perform_later, ->(*) { flunk('compute.after_save must not be deferred to UpdateAsyncComputedPropertiesJob') }) do
              content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

              assert_equal([@tags['Tag 2'].classification_id], primary_icon_ids(content))
            end
          end
        end

        test 'a fresh read sees the value as soon as the save returns' do
          with_icons do
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

            # not content.reload — a completely separate instance, as the request rendering the
            # detail view after the save-redirect would load it
            assert_equal(
              [@tags['Tag 2'].classification_id],
              Array.wrap(DataCycleCore::Thing.find(content.id).get_data_hash['primary_icon_classifications'])
            )
          end
        end

        test 'the compute observes the persisted classifications, not the pre-save state' do
          with_icons do
            # the fallback reads collected_classification_contents, which its triggers only fill
            # once the classification_contents rows are written — an inline before_save compute
            # would see nothing here and store an empty icon
            content = create_content('universal_classifications' => [@tags['Nested Tag 1'].classification_id])

            assert_equal([@tags['Tag 3'].classification_id], primary_icon_ids(content))
          end
        end

        test 'compute.after_save keys are excluded from the inline before_save pass' do
          content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

          assert_includes content.after_save_computed_property_names, 'primary_icon_classifications'
          assert_not_includes content.inline_computed_property_names, 'primary_icon_classifications'
        end

        test 'the recompute keeps the acting user as updated_by' do
          with_icons do
            user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

            content.set_data_hash(data_hash: { 'universal_classifications' => [@tags['Tag 3'].classification_id] }, current_user: user)

            reloaded = DataCycleCore::Thing.find(content.id)

            assert_equal([@tags['Tag 3'].classification_id], Array.wrap(reloaded.get_data_hash['primary_icon_classifications']))
            assert_equal(user.id, reloaded.updated_by, 'the recompute must not blank the editor out of updated_by')
          end
        end

        test 'update_computed: false skips the after_save recompute' do
          with_icons do
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

            content.stub(:update_after_save_computed_values, ->(*) { flunk('update_computed: false must not recompute') }) do
              content.set_data_hash(
                data_hash: { 'universal_classifications' => [@tags['Tag 3'].classification_id] },
                update_computed: false
              )
            end

            assert_equal([@tags['Tag 2'].classification_id], primary_icon_ids(content), 'the caller opted out, so the stored icon stays as it was')
          end
        end

        # ---------- the recompute must not leak caller-facing state (review round 1) ----------

        test 'an icon-neutral classification change does not report "no changes"' do
          with_icons do
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

            # "Markt 1" has no icon, so the recompute finds the same value and falls out on
            # no_changes — whose warning must not reach the caller, which reads warnings as
            # "nothing was stored" (ContentsController#update)
            content.set_data_hash(
              data_hash: { 'universal_classifications' => [@tags['Tag 2'].classification_id, @markets['Markt 1'].classification_id] }
            )

            assert_empty(content.warnings.messages, "the recompute's no_changes must not surface as a caller warning")
            assert_equal([@tags['Tag 2'].classification_id], primary_icon_ids(content))
          end
        end

        test 'a recompute that fails validation rolls the save back and reports failure' do
          with_icons do
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

            # fail validation for the recompute pass only (data_hash holding just the computed key)
            failing_validate = lambda do |**kwargs|
              next true unless kwargs[:data_hash]&.keys == ['primary_icon_classifications']

              content.errors.add(:primary_icon_classifications, 'probe forced failure')
              false
            end

            result = content.stub(:validate, failing_validate) do
              content.set_data_hash(data_hash: { 'universal_classifications' => [@tags['Tag 3'].classification_id] })
            end

            assert_not(result, 'set_data_hash must report failure when the recompute cannot be stored')

            reloaded = DataCycleCore::Thing.find(content.id)

            assert_equal(
              [@tags['Tag 2'].classification_id],
              Array.wrap(reloaded.get_data_hash['universal_classifications']),
              'the save must be rolled back rather than committed with a stale computed value'
            )
          end
        end

        test 'the recompute inherits prevent_history and version_name from the triggering save' do
          with_icons do
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

            content.set_data_hash(
              data_hash: { 'universal_classifications' => [@tags['Tag 3'].classification_id] },
              prevent_history: true,
              version_name: 'probe version'
            )

            reloaded = DataCycleCore::Thing.find(content.id)

            assert_equal([@tags['Tag 3'].classification_id], Array.wrap(reloaded.get_data_hash['primary_icon_classifications']))
            assert_not(reloaded.write_history, 'prevent_history must still hold after the recompute')
            assert_equal('probe version', reloaded.version_name, 'the recompute must not blank the version name')
          end
        end

        test 'the recompute does not emit its own webhooks or notify subscribers' do
          with_icons do
            user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])
            webhooks = []
            mails = 0

            DataCycleCore::Webhook::Update.stub(:execute_all, ->(*) { webhooks << :update }) do
              DataCycleCore::SubscriptionMailer.stub(:notify, ->(*) { mails += 1 and OpenStruct.new(deliver_later: true) }) do # rubocop:disable Style/OpenStructUse
                content.set_data_hash(
                  data_hash: { 'universal_classifications' => [@tags['Tag 3'].classification_id] },
                  current_user: user
                )
              end
            end

            assert_equal(1, webhooks.size, 'one save must emit exactly one update webhook, not one per pass')
            assert_equal(0, mails, 'the recompute must not notify subscribers a second time')
          end
        end

        test 'a newly created content emits the create webhook before any update webhook' do
          with_icons do
            order = []

            DataCycleCore::Webhook::Create.stub(:execute_all, ->(*) { order << :create }) do
              DataCycleCore::Webhook::Update.stub(:execute_all, ->(*) { order << :update }) do
                # unique name: TestPreparations reuses an existing content by name, which would
                # skip the create webhook and make this order test depend on test order
                DataCycleCore::TestPreparations.create_content(
                  template_name: 'PrimaryIcon-Place',
                  data_hash: {
                    'name' => "Primary Icon Webhook Order #{SecureRandom.hex(6)}",
                    'universal_classifications' => [@tags['Tag 2'].classification_id]
                  }
                )
              end
            end

            assert_equal([:create, :update], order, 'the recompute must not slip an update webhook in before the create')
          end
        end

        test 'a recompute that arrives at the same value does not write again' do
          with_icons do
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

            # "Markt 1" carries no icon, so the icon stays Tag 2: the recompute runs but its
            # set_data_hash has to fall out on no_changes instead of storing/versioning again
            content.set_data_hash(
              data_hash: { 'universal_classifications' => [@tags['Tag 2'].classification_id, @markets['Markt 1'].classification_id] }
            )

            assert_equal([@tags['Tag 2'].classification_id], primary_icon_ids(content))
            assert_not_includes(
              content.previous_datahash_changes.to_h.keys,
              'primary_icon_classifications',
              'an unchanged computed value must not cause a second write'
            )
          end
        end

        test 'a failing recompute propagates instead of being downgraded to the async job' do
          with_icons do
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])
            enqueued = []

            DataCycleCore::UpdateAsyncComputedPropertiesJob.stub(:perform_later, ->(*args) { enqueued << args }) do
              # the template's only compute is the after_save one, so this hits exactly that pass
              DataCycleCore::Utility::Compute::Base.stub(:compute_values, ->(*) { raise 'compute exploded' }) do
                assert_raises(RuntimeError, 'the error must surface like a failing inline compute') do
                  content.set_data_hash(data_hash: { 'universal_classifications' => [@tags['Tag 3'].classification_id] })
                end
              end
            end

            assert_empty(enqueued, 'a failure must not be silently downgraded to a background job')

            # the recompute runs inside set_data_hash's own write transaction, so a bare
            # set_data_hash is rolled back just like the editor path (see ComputedAfterSaveTest)
            assert_equal(
              [@tags['Tag 2'].classification_id],
              Array.wrap(DataCycleCore::Thing.find(content.id).get_data_hash['universal_classifications']),
              'the write must be rolled back with the failing recompute'
            )
          end
        end

        test 'a save that changes nothing relevant does not recompute' do
          with_icons do
            content = create_content('universal_classifications' => [@tags['Tag 2'].classification_id])

            assert_equal([@tags['Tag 2'].classification_id], primary_icon_ids(content))

            # 'name' is not a compute parameter, so no after_save pass may be triggered
            content.stub(:update_computed_values_for_locale, ->(**) { flunk('unrelated changes must not trigger the after_save recompute') }) do
              content.set_data_hash(data_hash: { 'name' => 'Primary Icon Test renamed' })
            end

            assert_equal([@tags['Tag 2'].classification_id], primary_icon_ids(content))
          end
        end
      end
    end
  end
end
