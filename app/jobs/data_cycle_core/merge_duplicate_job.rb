# frozen_string_literal: true

module DataCycleCore
  class MergeDuplicateJob < ApplicationJob
    # there is a bug in ActiveJob in combination with DelayedJob that prevents
    # @provider_job_id to be available in the perform actions and callbacks!!
    # it is available in the enque-callbacks
    queue_as :default

    def perform(original_id, duplicate_id)
      return if duplicate_id.blank? || original_id.blank?
      original = DataCycleCore::Thing.find_by(id: original_id)
      duplicate = DataCycleCore::Thing.find_by(id: duplicate_id)
      return if original.nil? || duplicate.nil? || original.template_name != duplicate.template_name

      existing_query = original.content_content_b.map { |c| "(content_contents.content_a_id = '#{c.content_a_id}' AND content_contents.relation_a = '#{c.relation_a}')" }.join(' OR ')

      query1 = duplicate.content_content_b.includes(:content_a)
      query1 = query1.where.not(existing_query) if existing_query.present?
      valid = true

      query1.find_each do |linked_content|
        save_time = Time.zone.now
        content = linked_content.content_a
        update_contents = [content]

        if content.embedded?
          update_contents.concat(Array.wrap(content.related_contents(embedded: true)))
          content = content.related_contents.first
        end

        next if content.nil?
        if DataCycleCore::Feature::ContentLock.enabled? && content.locked?
          valid = false
          next
        end

        content.to_history(save_time: save_time)
        update_contents.each do |c|
          c.update_columns(updated_at: save_time, updated_by: nil)
        end
        linked_content.update_column(:content_b_id, original.id)
        content.send(:execute_update_webhooks)
      end

      raise 'locked Contents!' unless valid

      duplicate_external_key = duplicate.external_key
      duplicate_external_source_id = duplicate.external_source_id

      ActiveRecord::Base.transaction do
        duplicate.original_id = original.id
        duplicate_sync_query(original.external_source_id, original.external_key, duplicate.id, original.id).update_all(syncable_id: original.id)
        duplicate.destroy_content

        if duplicate_external_source_id.present? && duplicate_external_key.present? && (original.external_source_id != duplicate_external_source_id || original.external_key != duplicate_external_key)
          duplicate_external_key.split(';').reject(&:blank?).each do |d_external_key|
            original.external_system_syncs.find_or_create_by!(external_system_id: duplicate_external_source_id, external_key: d_external_key, sync_type: 'duplicate')
          end
        end
      end
    end

    private

    def duplicate_sync_query(external_system_id, external_key, duplicate_id, original_id)
      syncs_sql = <<-SQL
        WITH syncs_table AS (
          SELECT
            s1.id
          FROM
            external_system_syncs s1
          WHERE
            s1.syncable_type = 'DataCycleCore::Thing'
            AND s1.syncable_id = :id
            AND s1.sync_type != 'export'
            AND s1.external_system_id != :external_system_id
            AND NOT EXISTS (
              SELECT 1 FROM external_system_syncs s2
              WHERE s2.syncable_type = s1.syncable_type
              AND s2.syncable_id = :new_id
              AND s2.sync_type = s1.sync_type
              AND s2.external_system_id = s1.external_system_id
              AND s2.external_key = s1.external_key
            )
          UNION
          SELECT
            s3.id
          FROM
            external_system_syncs s3
          WHERE
            s3.syncable_type = 'DataCycleCore::Thing'
            AND s3.syncable_id = :id
            AND s3.sync_type != 'export'
            AND s3.external_key != :external_key
            AND s3.external_system_id IS NOT NULL
            AND NOT EXISTS (
              SELECT 1 FROM external_system_syncs s4
              WHERE s4.syncable_type = s3.syncable_type
              AND s4.syncable_id = :new_id
              AND s4.sync_type = s3.sync_type
              AND s4.external_system_id = s3.external_system_id
              AND s4.external_key = s3.external_key
            )
        )
        SELECT id FROM syncs_table
      SQL

      DataCycleCore::ExternalSystemSync.where("external_system_syncs.id IN (#{syncs_sql})", external_system_id: external_system_id, external_key: external_key, id: duplicate_id, new_id: original_id)
    end
  end
end
