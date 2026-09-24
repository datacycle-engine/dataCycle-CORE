# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      # [#51643] End-to-end coverage of the _generated companion mechanism wired into a template:
      # the companion is only computed while the editorial attribute is empty, the content is marked
      # with an ArtificialIntelligenceAgent while a generated value is effective, and the marking is
      # a content_content_links relation the dashboard's graph_filter can select.
      class ComputedGeneratedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        DEGREE = DataCycleCore::Utility::Compute::Generated::DEFAULT_DEGREE

        # Absolute counts elsewhere in the suite depend on no test leaving contents behind -
        # creative_work_history_test asserts Thing::History.count and filter_common_coverage_test
        # counts whole result sets - and this suite does not roll back between tests. The async
        # recompute also stores through a set_data_hash of its own, without the options of the save
        # that scheduled it, so it writes history whatever this test asks for.
        after(:all) do
          DataCycleCore::Thing
            .where(template_name: ['Generated-Image', 'Generated-Overlay-Image', 'Generated-AfterSave-Image', DataCycleCore::AiAgentService::TEMPLATE_NAME])
            .destroy_all
          DataCycleCore::Thing::History::Translation.delete_all
          DataCycleCore::Thing::History.delete_all
        end

        # The companion is computed by a job, and the marking by a job that the companion's own
        # save enqueues - so the queue has to be drained rather than flushed once, the way a worker
        # would work through it.
        def settle_jobs(limit = 10)
          limit.times do
            break if enqueued_jobs.empty?

            perform_enqueued_jobs
          end
        end

        # A unique name per image: TestPreparations.create_content returns the existing content when
        # one of that template already carries the name, and this suite does not roll back between
        # tests, so a shared name would hand the next test an already marked image.
        def create_image(name, description = nil)
          create_content('Generated-Image', { 'name' => name, 'description' => description }.compact)
            .tap { settle_jobs }
        end

        # Same companion next to an attribute that carries an overlay, so what decides whether the
        # generated value is effective is description_overlay - the override where an editor set
        # one, the base where none is.
        def create_overlay_image(name, override = nil)
          create_content('Generated-Overlay-Image', { 'name' => name, 'description_override' => override }.compact)
            .tap { settle_jobs }
        end

        def update_image(content, data_hash)
          update_content(content, data_hash).tap { settle_jobs }
        end

        def data_hash_of(content)
          content.reload.get_data_hash
        end

        def agent_ids(content)
          Array.wrap(data_hash_of(content)['contributor_generated'])
        end

        def degree_concept
          DataCycleCore::Concept
            .for_tree(DataCycleCore::AiAgentService::CONCEPT_SCHEME)
            .find_by!(external_key: DEGREE)
        end

        test 'the companion is computed and marked while the editorial attribute is empty' do
          image = create_image('Lavendelfeld generiert')

          assert_equal('Lavendelfeld generiert', data_hash_of(image)['description_generated'])
          assert_equal(1, agent_ids(image).size)
          assert_equal([degree_concept.id], Array.wrap(data_hash_of(image)['dc_ai_degree_of_involvement']))
        end

        test 'the agent is the collective AI agent of AiAgentService' do
          image = create_image('Lavendelfeld Agent')
          agent = DataCycleCore::Thing.find(agent_ids(image).first)

          assert_equal(DataCycleCore::AiAgentService::TEMPLATE_NAME, agent.template_name)
          assert_equal("#{DataCycleCore::AiAgentService::DEFAULT_NAME}#{DataCycleCore::AiAgentService::KEY_SEPARATOR}#{DEGREE}", agent.external_key)
        end

        test 'an editorially filled attribute is neither generated nor marked' do
          image = create_image('Lavendelfeld redaktionell', 'Redaktionelle Beschreibung')

          assert_nil(data_hash_of(image)['description_generated'])
          assert_empty(agent_ids(image))
          assert_empty(Array.wrap(data_hash_of(image)['dc_ai_degree_of_involvement']))
        end

        test 'an editorial value arriving later ends the marking' do
          image = create_image('Lavendelfeld nachgetragen')

          assert_equal(1, agent_ids(image).size)

          update_image(image, data_hash_of(image).merge('description' => 'Redaktionell nachgetragen'))

          assert_empty(agent_ids(image))
        end

        # A generated value stays stored when the editorial one arrives, so clearing the editorial
        # attribute again costs no new request - and the marking comes back with it.
        test 'clearing the editorial value again restores value and marking' do
          image = create_image('Lavendelfeld geleert', 'Redaktionell')

          update_image(image, data_hash_of(image).merge('description' => nil))

          assert_equal('Lavendelfeld geleert', data_hash_of(image)['description_generated'])
          assert_equal(1, agent_ids(image).size)
        end

        # The companion's own :parameters: name the annotation source, not the editorial attribute -
        # only the injected condition ties it to that one, and Content#compute_dependency_names is
        # what turns the condition into the dependency.
        test 'the injected condition makes the base attribute a dependency of the companion' do
          template = DataCycleCore::Thing.new(thing_template: DataCycleCore::ThingTemplate.find_by(template_name: 'Generated-Image'))

          assert_includes(template.dependent_computed_property_names(['description']), 'description_generated')
          assert_includes(template.flat_dependent_computed_property_names(['description']), 'contributor_generated')
        end

        # A producer may derive one locale from another - the imageDescriptionPixie translates the
        # editorial ALT label into the languages it does not annotate - and flat_computed_parameters
        # resolves parameters within one locale, so it cannot express that. The editorial attribute
        # changing in one locale therefore has to reschedule the companion in the others; which of
        # them then has anything to do is left to the injected condition.
        test 'an editorial value reschedules the companion in the other locales' do
          image = create_image('Lavendelfeld mehrsprachig')
          I18n.with_locale(:en) { update_image(image, { 'name' => 'Lavender field' }) }

          assert_equal(['de', 'en'], image.reload.available_locales.map(&:to_s).sort)

          clear_enqueued_jobs
          # the entry point of an editor save (ContentsController#update) and of an import
          # (DataHashService), and the only one that weighs the locales it did not write
          I18n.with_locale(:de) { image.set_data_hash_with_translations(data_hash: data_hash_of(image).merge('description' => 'Redaktionell')) }

          rescheduled = enqueued_jobs.select { |job| job[:job] == DataCycleCore::UpdateTranslatedComputedPropertiesJob }

          assert_equal(1, rescheduled.size)
          assert_equal([image.id, ['en']], rescheduled.first[:args].first(2))
          assert_includes(rescheduled.first[:args].third, 'description_generated')

          settle_jobs
        end

        # The reschedule weighs every locale a save wrote, not the last of them: an editor filling
        # the German description and renaming the English one in the same save leaves Italian to
        # catch up, and only the German key names the companion.
        test 'a save writing two locales weighs both of them when rescheduling the third' do
          I18n.available_locales << :it
          image = create_image('Lavendelfeld dreisprachig')
          I18n.with_locale(:en) { update_image(image, { 'name' => 'Lavender field in three locales' }) }
          I18n.with_locale(:it) { update_image(image, { 'name' => 'Campo di lavanda' }) }

          assert_equal(['de', 'en', 'it'], image.reload.available_locales.map(&:to_s).sort)

          clear_enqueued_jobs
          I18n.with_locale(:de) do
            image.set_data_hash_with_translations(
              data_hash: { translations: { 'de' => { 'description' => 'Redaktionell mehrsprachig' }, 'en' => { 'name' => 'Lavender field renamed' } } }
            )
          end

          rescheduled = enqueued_jobs.select { |job| job[:job] == DataCycleCore::UpdateTranslatedComputedPropertiesJob }

          assert_equal(1, rescheduled.size)
          assert_equal([image.id, ['it']], rescheduled.first[:args].first(2))
          assert_includes(rescheduled.first[:args].third, 'description_generated')

          settle_jobs
        ensure
          I18n.available_locales.delete(:it)
        end

        # A project that swaps the service behind a companion attribute re-annotates whatever it
        # recomputes, because the annotation is kept per external system. The marking has to follow
        # that swap rather than collect both services: contributor_generated is computed with
        # :fallback: false, so a recompute stores exactly the agents currently effective.
        test 'a stale agent is replaced by the next recompute rather than kept alongside' do
          image = create_image('Lavendelfeld Anbieterwechsel')
          current = agent_ids(image)
          stale = DataCycleCore::AiAgentService.find_or_create(
            DataCycleCore::Generic::Common::DataReferenceTransformations::AiAgentReference.new(DEGREE, 'Vorheriger Dienst')
          )

          assert_equal(1, current.size)
          assert_not_equal(stale.id, current.first)

          update_image(image, { 'contributor_generated' => current + [stale.id] })

          assert_equal(2, agent_ids(image).size, 'the stale agent has to be stored for the recompute to have something to replace')

          image.update_computed_values(keys: ['contributor_generated'])
          settle_jobs

          assert_equal(current, agent_ids(image))
        end

        # [#51643] The marking is computed from the *stored* companion value
        # (Utility::Compute::Generated#effective_locales), and the job computing it is scheduled by
        # the companion's own save. Enqueued before that save was written, the job was claimable by
        # a free worker a poll earlier than the value it reads, which marks nothing and stores that
        # - :fallback: false. A Canto image of the backfill ended up exactly there: a generated ALT
        # label, an empty contributor_generated.
        test 'the marking job is enqueued only once the companion value it reads is stored' do
          stored_at_enqueue = []

          subscriber = ActiveSupport::Notifications.subscribe('enqueue.active_job') do |event|
            job = event.payload[:job]
            next unless job.is_a?(DataCycleCore::UpdateAsyncComputedPropertiesJob)

            keys = Array.wrap(job.arguments.second)
            next unless keys.include?('contributor_generated')
            # the save that computed the companion, not the creating one - that schedules the
            # companion and its marking in one job, where the companion is legitimately unstored
            next if keys.include?('description_generated')

            stored_at_enqueue << DataCycleCore::Thing.find(job.arguments.first).description_generated
          end

          create_image('Lavendelfeld nebenlaeufig')

          assert_equal(['Lavendelfeld nebenlaeufig'], stored_at_enqueue)
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end

        # The compute.after_save pass runs its own #set_data_hash between the caller deferring its
        # async keys and draining them after the transaction, so a nested pass that discarded stale
        # deferrals would take the caller's with it and the companion would never be computed.
        test 'a nested compute.after_save pass leaves the async keys of the save it runs in' do
          image = DataCycleCore::TestPreparations.create_content(template_name: 'Generated-AfterSave-Image', data_hash: { 'name' => 'Lavendelfeld mit Notiz' })
          settle_jobs

          assert_equal('Lavendelfeld mit Notiz', data_hash_of(image)['after_save_note'], 'control: the compute.after_save pass has to have run')
          assert_equal('Lavendelfeld mit Notiz', data_hash_of(image)['description_generated'])
          assert_equal(1, agent_ids(image).size)
        end

        # A save that bails out between deferring its async keys and draining them wrote nothing,
        # so there is nothing to recompute from; leaving the keys on the object hands them to its
        # next save, which is how a rolled back save would still reach the queue.
        test 'a rolled back save leaves no async keys behind for the next one' do
          image = DataCycleCore::TestPreparations.create_content(template_name: 'Generated-AfterSave-Image', data_hash: { 'name' => 'Lavendelfeld zurueckgerollt' })
          settle_jobs

          rejected = ->(**) { { 'not' => 'a string' } }

          DataCycleCore::Utility::Compute::Common.stub(:copy, rejected) do
            assert_not(image.set_data_hash(data_hash: { 'name' => 'Lavendelfeld umbenannt' }), 'the recompute has to be rejected, otherwise the save drains the deferral itself')
          end

          assert_no_enqueued_jobs(only: DataCycleCore::UpdateAsyncComputedPropertiesJob) do
            image.set_data_hash(data_hash: {}, force_update: true)
          end
        end

        # How a machine-filled attribute is switched off and cleaned up (docs/generated_attributes.md):
        # the producer stops answering - Feature::ImageDescriptionPixie#generate? turning false for
        # these contents - and :fallback: false forbids restoring the stored value, so the backfill
        # empties the companion and the marking goes with it. There is no separate cleanup task.
        test 'a producer that no longer generates clears the value and the marking' do
          image = create_image('Lavendelfeld Abschaltung')

          assert_predicate(data_hash_of(image)['description_generated'], :present?)
          assert_equal(1, agent_ids(image).size)

          DataCycleCore::Utility::Compute::Common.stub(:copy, ->(**) {}) do
            image.update_computed_values(keys: ['description_generated'])
            settle_jobs
          end

          assert(DataCycleCore::DataHashService.blank?(data_hash_of(image)['description_generated']))
          assert_empty(agent_ids(image))
        end

        # The API delivers the overlay, not the base attribute an override leaves empty, so the
        # overlay is what the companion is weighed against - otherwise an overridden image keeps
        # generating and keeps claiming a text no consumer sees.
        #
        # That the generated value survives an override is what makes it safe to stop generating
        # while one is set: removing the override brings it back with no new request to the
        # producer, because the companion was never cleared, only left out of the API.
        test 'an override ends the generation and the marking, and removing it brings both back' do
          image = create_overlay_image('Lavendelfeld mit Overlay')

          assert_equal('Lavendelfeld mit Overlay', data_hash_of(image)['description_generated'])
          assert_equal(1, agent_ids(image).size)

          update_image(image, { 'description_override' => 'Redaktionelles Overlay' })

          # virtual, so it is read off the content rather than out of the data hash
          assert_equal('Redaktionelles Overlay', image.reload.description_overlay)
          assert_equal('Lavendelfeld mit Overlay', data_hash_of(image)['description_generated'], 'the generated value is left standing, not cleared')
          assert_empty(agent_ids(image))

          update_image(image, { 'description_override' => nil })

          assert_equal('Lavendelfeld mit Overlay', data_hash_of(image)['description_generated'])
          assert_equal(1, agent_ids(image).size)
        end

        # Nothing gates the recompute on the companion being empty: an image that carried an
        # override from the start has never generated, and removing it has to generate for the
        # first time - which is the run that actually costs the producer a request.
        test 'an image that never generated because of an override generates once it is removed' do
          image = create_overlay_image('Lavendelfeld von Anfang an ueberschrieben', 'Redaktionell von Anfang an')

          assert(DataCycleCore::DataHashService.blank?(data_hash_of(image)['description_generated']))
          assert_empty(agent_ids(image))

          update_image(image, { 'description_override' => nil })

          assert_equal('Lavendelfeld von Anfang an ueberschrieben', data_hash_of(image)['description_generated'])
          assert_equal(1, agent_ids(image).size)
        end

        # One injected condition per editorial attribute an editor can write, which is what makes
        # both of them dependencies of the companion - and that is what schedules the recompute
        # when an override is written or removed.
        test 'the injected conditions name every editorial attribute and make each a dependency' do
          image = create_overlay_image('Lavendelfeld Overlay-Abhaengigkeit')
          condition_names = image.properties_for('description_generated').dig('compute', 'condition').pluck('name')

          assert_equal(['description', 'description_override'], condition_names.sort)

          ['description', 'description_override'].each do |key|
            assert_includes(image.send(:flat_dependent_computed_property_names, [key]), 'description_generated')
          end
        end

        # Cross-locale: an override written in one language has to re-weigh the companion in the
        # others, the same way the base attribute does.
        test 'an override reschedules the companion in the other locales' do
          image = create_overlay_image('Lavendelfeld Overlay mehrsprachig')

          assert_equal(['description_generated'], image.send(:generated_companions_to_recompute, ['description_override']))
          assert_equal(['description_generated'], image.send(:generated_companions_to_recompute, ['description']))
        end

        test 'the marking is a contributor_generated relation the graph_filter selects' do
          marked = create_image('Lavendelfeld gefiltert')
          unmarked = create_image('Bergsee gefiltert', 'Redaktionell')

          assert_includes(DataCycleCore::Feature::AdvancedFilter.graph_filter_relations, 'contributor_generated')

          filtered = DataCycleCore::Filter::Search
            .new(locale: :de)
            .template_names('Generated-Image')
            .graph_filter(nil, 'contributor_generated', 'linked_items_in')
            .map(&:id)

          assert_includes(filtered, marked.id)
          assert_not_includes(filtered, unmarked.id)
        end
      end
    end
  end
end
