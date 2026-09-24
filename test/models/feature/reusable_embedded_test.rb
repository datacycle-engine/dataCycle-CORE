# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class ReusableEmbeddedTest < DataCycleCore::TestCases::ActiveSupportTestCase
      SUBJECT = DataCycleCore::Feature::ReusableEmbedded

      def create_parent(embedded)
        DataCycleCore::TestPreparations.create_content(
          template_name: 'Embedded-Entity-Reusable',
          data_hash: { 'name' => 'reusable-parent', 'embedded_creative_work' => [embedded.merge('template_name' => 'Embedded-Creative-Work-Reusable')] }
        )
      end

      test 'reusable_templates keeps the embedded templates, which carry the injected flag' do
        names = ['Embedded-Creative-Work-2', 'Embedded-Creative-Work-Reusable', 'Embedded-Entity-Reusable', 'Does-Not-Exist']

        assert_equal ['Embedded-Creative-Work-2', 'Embedded-Creative-Work-Reusable'], SUBJECT.reusable_templates(names)
      end

      test 'the importer adds the flag to embedded templates only' do
        assert_equal 'boolean', DataCycleCore::ThingTemplate.find_by(template_name: 'Embedded-Creative-Work-2').schema.dig('properties', 'reusable', 'type')
        assert_nil DataCycleCore::ThingTemplate.find_by(template_name: 'Embedded-Entity-Reusable').schema.dig('properties', 'reusable')
      end

      test 'reusable_templates is empty while the feature is disabled' do
        SUBJECT.stub(:enabled?, false) do
          assert_empty SUBJECT.reusable_templates('Embedded-Creative-Work-Reusable')
        end
      end

      test 'reusable? is true once the flag classification is set' do
        parent = create_parent({ 'name' => 'block', 'reusable' => true })

        assert_predicate parent.embedded_creative_work.first, :reusable?
      end

      test 'reusable? is false without the flag and for the parent' do
        parent = create_parent({ 'name' => 'block' })

        assert_not parent.embedded_creative_work.first.reusable?
        assert_not parent.reusable?
      end

      def create_shared_setup
        parent = DataCycleCore::TestPreparations.create_content(
          template_name: 'Embedded-Entity-Reusable',
          data_hash: {
            'name' => 'first parent',
            'embedded_creative_work' => [
              { 'template_name' => 'Embedded-Creative-Work-Reusable', 'name' => 'shared block', 'reusable' => true },
              { 'template_name' => 'Embedded-Creative-Work-Reusable', 'name' => 'own block' }
            ]
          }
        )
        shared, own = parent.embedded_creative_work.to_a
        second = DataCycleCore::TestPreparations.create_content(
          template_name: 'Embedded-Entity-Reusable',
          data_hash: { 'name' => 'second parent', 'embedded_creative_work' => [{ 'id' => shared.id }] }
        )

        [parent, second, shared, own]
      end

      def embedded_hashes(parent)
        parent.embedded_creative_work.map { |e| { 'id' => e.id, 'template_name' => e.template_name } }
      end

      test 'duplicating a content links flagged embedded and copies the rest' do
        parent, _second, shared, own = create_shared_setup

        duplicate = parent.create_duplicate

        assert duplicate
        ids = duplicate.embedded_creative_work.pluck(:id)

        assert_includes ids, shared.id
        assert_not_includes ids, own.id
        assert_equal 3, shared.content_a.count
        assert_equal 1, own.content_a.count
      end

      test 'removing a shared block from one parent keeps it for the other' do
        parent, second, shared, _own = create_shared_setup

        parent.set_data_hash(data_hash: { 'embedded_creative_work' => embedded_hashes(parent).reject { |h| h['id'] == shared.id } })

        assert_equal [second.id], shared.reload.content_a.pluck(:id)
      end

      test 'changing a shared block enqueues the fan-out to its other parents' do
        parent, _second, shared, own = create_shared_setup
        hashes = embedded_hashes(parent)

        DataCycleCore.stub(:webhooks, ['Reusable ES']) do
          parent.set_data_hash(data_hash: { 'embedded_creative_work' => hashes.map { |h| h['id'] == own.id ? h.merge('name' => 'own renamed') : h } })

          assert_empty fan_out_sources

          parent.set_data_hash(data_hash: { 'embedded_creative_work' => hashes.map { |h| h['id'] == shared.id ? h.merge('name' => 'shared renamed') : h } })

          assert_equal [[parent.id, shared.id]], fan_out_sources
        end
      end

      test 'a shared block counts distinct parents, not content_contents rows' do
        parent, second, shared, _own = create_shared_setup

        assert_equal [parent.id, second.id].sort, shared.reusable_parents.pluck(:id).sort
        assert_predicate shared, :shared_embedded?

        second.set_data_hash(data_hash: { 'embedded_creative_work' => [] })

        assert_not shared.reload.shared_embedded?
      end

      # content_property_dependencies derives from content_content_links, so the second parent depends
      # on the block as soon as it links it, and the block's save recomputes every parent
      test 'a computed attribute reading a shared block recomputes on every parent' do
        parent, second, shared, _own = create_shared_setup

        assert_equal 'shared block', second.reload.first_block_name

        parent.set_data_hash(data_hash: { 'embedded_creative_work' => embedded_hashes(parent).map { |h| h['id'] == shared.id ? h.merge('name' => 'shared renamed') : h } })
        perform_enqueued_jobs

        assert_equal 'shared renamed', parent.reload.first_block_name
        assert_equal 'shared renamed', second.reload.first_block_name
      end

      # the parent has no linkers of its own, so only a changed shared block enqueues the fan-out
      def fan_out_sources
        enqueued_jobs.select { |j| j[:job] == DataCycleCore::RelatedWebhooksJob }.map { |j| j[:args].first }
      end
    end
  end
end
