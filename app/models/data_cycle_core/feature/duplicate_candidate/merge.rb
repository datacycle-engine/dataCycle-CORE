# frozen_string_literal: true

module DataCycleCore
  module Feature
    class DuplicateCandidate < Base
      # merges a duplicate into its original: moves every content linking to the duplicate over
      # to the original, copies the duplicate's external_system_syncs and finally deletes it.
      #
      # merging is idempotent - a moved link no longer points at the duplicate, so a pair that
      # was only merged part way through (e.g. because a linked content was locked) can safely
      # be merged again by MergeDuplicateJob.
      class Merge
        # raised when a content linking to the duplicate is locked: its link stays where it is,
        # so the merge has to be repeated once the lock is gone
        class LockedContentsError < StandardError; end

        # merges the pair right away, see #call
        def self.call(...)
          new(...).call
        end

        def initialize(original:, duplicate:, current_user: nil)
          @original = original
          @duplicate = duplicate
          @current_user = current_user
        end

        # returns false if the pair cannot be merged at all
        def call
          return false unless mergeable?

          move_linked_contents
          destroy_duplicate

          true
        end

        private

        attr_reader :original, :duplicate, :current_user

        def mergeable?
          original.present? &&
            duplicate.present? &&
            original.id != duplicate.id &&
            original.template_name == duplicate.template_name
        end

        # moves every content linking to the duplicate over to the original. locked contents are
        # left untouched and raise once the rest is moved, so that the remaining links are moved
        # as soon as the lock is gone.
        def move_linked_contents
          locked = false

          linked_contents.find_each do |linked_content|
            locked = true unless move_linked_content(linked_content)
          end

          raise LockedContentsError, "locked contents prevented merging #{duplicate.id} into #{original.id}" if locked
        end

        # links to the duplicate, skipping the ones the original already has
        def linked_contents
          existing_query = original.content_content_b.map { |c| "(content_contents.content_a_id = '#{c.content_a_id}' AND content_contents.relation_a = '#{c.relation_a}')" }.join(' OR ')
          scope = duplicate.content_content_b.includes(:content_a)

          existing_query.present? ? scope.where.not(existing_query) : scope
        end

        # returns false if the linking content is locked and could not be moved
        def move_linked_content(linked_content) # rubocop:disable Naming/PredicateMethod
          save_time = Time.zone.now
          content = linked_content.content_a
          update_contents = [content]

          if content.embedded?
            update_contents.concat(Array.wrap(content.related_contents(embedded: true)))
            content = content.related_contents.first
          end

          return true if content.nil?
          return false if DataCycleCore::Feature::ContentLock.enabled? && content.locked?

          content.to_history
          update_contents.each do |c|
            c.update_columns(updated_at: save_time, updated_by: nil, cache_valid_since: save_time)
          end

          original.update_columns(aggregate_type: 'belongs_to_aggregate') if linked_content.relation_b == 'belongs_to_aggregate' && !original.aggregate_type_belongs_to_aggregate?

          linked_content.update_column(:content_b_id, original.id)
          # the update_columns above move the timestamps of this content, and so its own payload
          # cache key; the contents linking it keep theirs, and nothing else here invalidates them
          content.send(:execute_update_webhooks, invalidate_related_cache: true) unless content.embedded?

          true
        end

        # deletes the duplicate and moves its history and external keys over to the original
        def destroy_duplicate
          external_key = duplicate.external_key || duplicate.id
          external_source_id = duplicate.external_source_id

          ActiveRecord::Base.transaction do
            duplicate.original_id = original.id
            copy_external_system_syncs

            original.thing_history_links << duplicate.thing_history_links

            duplicate.destroy(current_user:)

            link_delete_history
            copy_external_keys(external_source_id, external_key)
          end
        end

        # the duplicate's delete history entry documents the merge on the original as well
        def link_delete_history
          delete_history = DataCycleCore::Thing::History.where(id: duplicate.history_ids).where.not(deleted_at: nil).first
          return if delete_history.blank?

          DataCycleCore::ThingHistoryLink.create!(thing_id: original.id, thing_history_id: delete_history.id)
        end

        # keeps the duplicate's external keys importable on the original
        def copy_external_keys(external_source_id, external_key)
          return if external_source_id.blank? || external_key.blank?
          return if original.external_source_id == external_source_id && original.external_key == external_key

          external_key.split(';').compact_blank.each do |key|
            original.external_system_syncs.find_or_create_by!(
              external_system_id: external_source_id,
              external_key: key,
              sync_type: DataCycleCore::ExternalSystemSync::SYNC_TYPES[:import]
            )
          end
        end

        def copy_external_system_syncs
          column_names = DataCycleCore::ExternalSystemSync
            .column_names
            .except(['id', 'sync_type', 'syncable_id'])
            .sort

          select_columns = column_names + [
            'sync_type',
            'syncable_id'
          ]

          insert_columns = column_names + [
            "CASE WHEN sync_type = '#{DataCycleCore::ExternalSystemSync::SYNC_TYPES[:import]}' THEN sync_type ELSE '#{DataCycleCore::ExternalSystemSync::SYNC_TYPES[:duplicate]}' END AS sync_type",
            "'#{original.id}'::UUID AS syncable_id"
          ]

          insert_sql = <<~SQL.squish
            INSERT INTO #{DataCycleCore::ExternalSystemSync.table_name}(#{select_columns.join(', ')})
            SELECT #{insert_columns.join(', ')}
            FROM #{DataCycleCore::ExternalSystemSync.table_name}
            WHERE syncable_id = :duplicate_id
            AND syncable_type = :model_name
            AND NOT (external_system_id = :original_system_id AND external_key = :original_external_key AND sync_type = :sync_type)
            ON CONFLICT DO NOTHING
          SQL

          ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.send(
              :sanitize_sql_array, [
                insert_sql,
                {
                  duplicate_id: duplicate.id,
                  model_name: duplicate.model_name.to_s,
                  original_system_id: original.external_source_id,
                  original_external_key: original.external_key,
                  sync_type: DataCycleCore::ExternalSystemSync::SYNC_TYPES[:duplicate]
                }
              ]
            )
          )
        end
      end
    end
  end
end
