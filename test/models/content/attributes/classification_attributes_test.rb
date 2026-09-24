# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      # [#45466] Classification properties as typed attributes (Attributes::ClassificationAttributes):
      # assignment stays in memory with dirty tracking, the Thing's save persists it through autosave.
      class ClassificationAttributesTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @tags = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 1', 'Tag 2', 'Tag 3').order(:name).to_a
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Classification Attributes' })
        end

        def fresh_content
          DataCycleCore::Thing.find(@content.id)
        end

        def persisted_ids(content)
          DataCycleCore::ConceptContent.where(content_data_id: content.id, relation: 'tags').pluck(:concept_id).sort
        end

        # data_type carries a default value, so the association holds more than the tags rows
        def tag_rows(content)
          content.concept_contents.select { |cc| cc.relation == 'tags' }
        end

        test 'assigning ids, records or a mix of both builds rows in memory only' do
          content = fresh_content

          assert_no_changes -> { persisted_ids(content) } do
            content.tags = [@tags[0].id, @tags[1]]
          end

          assert_equal [@tags[0].id, @tags[1].id].sort, content.tags.pluck(:id).sort
          assert tag_rows(content).all?(&:new_record?)
          assert_predicate content, :tags_changed?
          assert_empty content.tags_was
        end

        test 'a single id or record is accepted like a one-element array' do
          content = fresh_content

          content.tags = @tags[0].id

          assert_equal [@tags[0].id], content.tags.pluck(:id)

          content.tags = @tags[1]

          assert_equal [@tags[1].id], content.tags.pluck(:id)
        end

        test 'save persists the rows, reload reads them back' do
          content = fresh_content
          content.tags = @tags.first(2)
          content.save!

          assert_equal @tags.first(2).map(&:id).sort, persisted_ids(content)
          assert_not_predicate content, :tags_changed?
          assert_equal [[], @tags.first(2).map(&:id).sort], content.saved_changes['tags']
          assert_equal @tags.first(2).map(&:id).sort, content.reload.tags.pluck(:id).sort
        end

        test 'the same ids in a different order are not a change' do
          content = fresh_content
          content.tags = @tags.first(2)
          content.save!

          content.tags = [@tags[1], @tags[0].id]

          assert_not_predicate content, :tags_changed?
          assert_equal 2, tag_rows(content).size, 'must not build duplicate rows'
        end

        test 'nil or [] marks the rows for destruction and deletes them on save' do
          content = fresh_content
          content.tags = @tags.first(2)
          content.save!

          content.tags = nil

          assert_predicate content, :tags_changed?
          assert_empty content.tags
          assert tag_rows(content).all?(&:marked_for_destruction?)
          assert_equal 2, persisted_ids(content).size, 'must not delete before save'

          content.save!

          assert_empty persisted_ids(content)
          assert_empty content.reload.tags
        end

        test 'replacing part of the ids removes only the dropped rows' do
          content = fresh_content
          content.tags = @tags.first(2)
          content.save!
          kept = tag_rows(content).detect { |cc| cc.concept_id == @tags[0].id }

          content.tags = [@tags[0], @tags[2]]

          assert_not_predicate kept, :marked_for_destruction?
          assert_equal [@tags[0].id, @tags[2].id].sort, content.tags.pluck(:id).sort

          content.save!

          assert_equal [@tags[0].id, @tags[2].id].sort, persisted_ids(content)
        end

        test 'restore_tags! reverts the attribute and save persists the restored ids' do
          content = fresh_content
          content.tags = [@tags[0]]
          content.save!

          content.tags = [@tags[1]]
          content.restore_tags!

          assert_not_predicate content, :tags_changed?
          assert_equal [@tags[0].id], content.tags.pluck(:id)

          content.save!

          assert_equal [@tags[0].id], persisted_ids(content)
        end

        test 'set_data_hash still writes classifications through the attribute' do
          content = fresh_content
          content.set_data_hash(data_hash: { tags: [@tags[2].id] }, prevent_history: true, update_search_all: false)

          assert_equal [@tags[2].id], persisted_ids(content)
          assert_equal [@tags[2].id], fresh_content.tags.pluck(:id)
        end

        # set_data_hash snapshots the previous state into a history right before it writes,
        # so the newest history holds the tags of the first call
        test 'histories expose the getter backed by concept_content_histories' do
          content = fresh_content
          content.set_data_hash(data_hash: { tags: [@tags[0].id] }, update_search_all: false)
          content.set_data_hash(data_hash: { tags: [@tags[1].id] }, update_search_all: false)

          assert_equal [@tags[0].id], content.histories.first.tags.pluck(:id)
        end
      end
    end
  end
end
