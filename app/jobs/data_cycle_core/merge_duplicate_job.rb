# frozen_string_literal: true

module DataCycleCore
  class MergeDuplicateJob < UniqueApplicationJob
    # there is a bug in ActiveJob in combination with DelayedJob that prevents
    # @provider_job_id to be available in the perform actions and callbacks!!
    # it is available in the enque-callbacks

    REFERENCE_TYPE = 'merge_duplicates'

    queue_as :default

    def delayed_reference_id
      "#{arguments[0]}_#{arguments[1]}"
    end

    def delayed_reference_type
      REFERENCE_TYPE
    end

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

        content.to_history
        update_contents.each do |c|
          c.update_columns(updated_at: save_time, updated_by: nil)
        end
        linked_content.update_column(:content_b_id, original.id)
        content.send(:execute_update_webhooks) unless content.embedded?
      end

      raise 'locked Contents!' unless valid

      duplicate_external_key = duplicate.external_key || duplicate.id
      duplicate_external_source_id = duplicate.external_source_id

      ActiveRecord::Base.transaction do
        duplicate.original_id = original.id
        duplicate_sync_query(duplicate.id, original.id)
        duplicate.destroy_content

        if duplicate_external_source_id.present? && duplicate_external_key.present? && (original.external_source_id != duplicate_external_source_id || original.external_key != duplicate_external_key)
          duplicate_external_key.split(';').reject(&:blank?).each do |d_external_key|
            original.external_system_syncs.find_or_create_by!(external_system_id: duplicate_external_source_id, external_key: d_external_key, sync_type: DataCycleCore::ExternalSystemSync::DUPLICATE_SYNC_TYPE)
          end
        end
      end
    end

    private

    def duplicate_sync_query(duplicate_id, original_id)
      column_names = DataCycleCore::ExternalSystemSync
        .column_names
        .except(['id', 'sync_type', 'syncable_id'])
        .sort

      select_columns = column_names + [
        'sync_type',
        'syncable_id'
      ]

      insert_columns = column_names + [
        "'#{DataCycleCore::ExternalSystemSync::DUPLICATE_SYNC_TYPE}' AS sync_type",
        "'#{original_id}'::UUID AS syncable_id"
      ]

      insert_sql = <<-SQL.squish
        INSERT INTO #{DataCycleCore::ExternalSystemSync.table_name}(#{select_columns.join(', ')})
        SELECT #{insert_columns.join(', ')}
        FROM #{DataCycleCore::ExternalSystemSync.table_name}
        WHERE syncable_id = :duplicate_id
        AND syncable_type = :model_name
        ON CONFLICT DO NOTHING
      SQL

      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(:sanitize_sql_array, [
                                  insert_sql,
                                  duplicate_id:,
                                  model_name: DataCycleCore::Thing.model_name.to_s
                                ])
      )
    end
  end
end
