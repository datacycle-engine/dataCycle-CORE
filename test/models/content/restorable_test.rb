# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    # Covers DataCycleCore::Content::Restorable (included into Thing::History):
    # recreating a destroyed Thing and all its history-backed associations.
    class RestorableTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @image = create_content('Bild', { name: 'Restorable Linked Image' })
        content = create_content('Artikel', {
          name: 'Restorable Article',
          tags: get_classification_ids('Tags', 'Tag 3'),
          image: [@image.id]
        })
        @thing_id = content.id
        content.destroy_content
      end

      def deletion_history
        DataCycleCore::Thing::History.where(thing_id: @thing_id).where.not(deleted_at: nil).first
      end

      test 'restore recreates the destroyed thing with its translations and links' do
        assert_nil DataCycleCore::Thing.find_by(id: @thing_id)

        history = deletion_history

        assert_not_nil history

        history.restore

        restored = DataCycleCore::Thing.find_by(id: @thing_id)

        assert_not_nil restored
        assert_equal('Restorable Article', restored.name)
        assert_predicate restored.classification_contents, :any?
        assert_includes restored.content_content_a.pluck(:content_b_id), @image.id
      end

      test 'restore_classification_contents swallows uniqueness conflicts' do
        history = deletion_history

        DataCycleCore::ClassificationContent.stub(:create!, ->(*, **) { raise ActiveRecord::RecordNotUnique }) do
          assert_nothing_raised { history.send(:restore_classification_contents) }
        end
      end

      test 'restore_content_contents handles embedded, linked and inverse links' do
        history = deletion_history

        embedded_history = Class.new {
          def embedded? = true
          def restore = nil
        }.new
        linked_history = Class.new {
          def embedded? = false
          def thing = Object.new
          def thing_id = 'linked-thing-id'
        }.new
        content_a_history = Class.new {
          def thing = Object.new
          def thing_id = 'parent-thing-id'
        }.new

        cc_embedded = struct_double(content_b_history_type: 'DataCycleCore::Thing::History', content_b_history: embedded_history)
        cc_linked_history = struct_double(content_b_history_type: 'DataCycleCore::Thing::History', content_b_history: linked_history, attributes: {})
        cc_live = struct_double(content_b_history_type: 'DataCycleCore::Thing', content_b_history_id: 'live-thing-id', attributes: {})
        cc_inverse = struct_double(content_a_history:, attributes: {})

        history.stub(:content_content_a_history, [cc_embedded, cc_linked_history, cc_live]) do
          history.stub(:content_content_b_history, [cc_inverse]) do
            DataCycleCore::ContentContent.stub(:create!, ->(*, **) { true }) do
              assert_nothing_raised { history.send(:restore_content_contents) }
            end

            DataCycleCore::ContentContent.stub(:create!, ->(*, **) { raise ActiveRecord::RecordNotUnique }) do
              assert_nothing_raised { history.send(:restore_content_contents) }
            end
          end
        end
      end

      test 'restore loops create records and swallow uniqueness conflicts' do
        history = deletion_history

        assert_restore_loop(history, :scheduled_history_data, DataCycleCore::Schedule, :restore_schedules)
        assert_restore_loop(history, :geometry_histories, DataCycleCore::Geometry, :restore_geometries)
        assert_restore_loop(history, :content_collection_link_histories, DataCycleCore::ContentCollectionLink, :restore_content_collection_links)
        assert_restore_loop(history, :embedding_histories, DataCycleCore::Embedding, :restore_embedding_histories)
      end

      private

      def assert_restore_loop(history, association, model, method)
        history.stub(association, [struct_double(attributes: {})]) do
          model.stub(:create!, ->(*, **) { true }) do
            assert_nothing_raised { history.send(method) }
          end

          model.stub(:create!, ->(*, **) { raise ActiveRecord::RecordNotUnique }) do
            assert_nothing_raised { history.send(method) }
          end
        end
      end
    end
  end
end
