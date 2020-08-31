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
        # rubocop:disable Rails/SkipsModelValidations
        update_contents.each do |c|
          c.update_columns(updated_at: save_time, updated_by: nil)
        end
        linked_content.update_column(:content_b_id, original.id)
        # rubocop:enable Rails/SkipsModelValidations
        content.send(:execute_update_webhooks)
      end

      raise 'locked Contents!' unless valid

      duplicate_external_key = duplicate.external_key
      duplicate_external_source_id = duplicate.external_source_id

      duplicate.original_id = original.id
      duplicate.destroy_content

      # rubocop:disable Rails/SkipsModelValidations
      if original.external_source_id == duplicate_external_source_id
        original.update_column(:external_key, original.external_key.to_s.split(';').to_set.merge(duplicate_external_key.to_s.split(';')).to_a.join(';').presence)
      elsif original.external_source_id.blank? && duplicate_external_source_id.present?
        original.update_columns(external_key: duplicate_external_key, external_source_id: duplicate_external_source_id)
      end
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
