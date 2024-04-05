# frozen_string_literal: true

module DataCycleCore
  class ClassificationMappingJob < ApplicationJob
    PRIORITY = 10

    before_enqueue :notify_with_lock

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      'data_cycle_core_classification_alias_update_mappings'
    end

    def perform(id, to_insert = [], to_delete = [])
      ca = DataCycleCore::ClassificationAlias.find_by(id:)

      return if ca.nil?

      insert_ids = Array.wrap(to_insert) - ca.classification_ids
      delete_ids = Array.wrap(to_delete).intersection(ca.classification_ids)

      read, write = IO.pipe
      pid = Process.fork do
        read.close

        if insert_ids.present?
          ca.classification_groups.insert_all(insert_ids.map { |cid| { classification_id: cid } }, unique_by: :classification_groups_ca_id_c_id_uq_idx, returning: false)

          DataCycleCore::Classification.where(id: insert_ids).find_each do |c|
            ca.send(:classifications_added, c)
          end
        end

        if delete_ids.present?
          ca.classification_groups.where(classification_id: delete_ids).delete_all

          DataCycleCore::Classification.where(id: delete_ids).find_each do |c|
            ca.send(:classifications_removed, c)
          end
        end

        ca.update(updated_at: Time.zone.now)
      rescue StandardError => e
        Marshal.dump({ error_class: e.class.name, error: e.to_s, backtrace: e.backtrace.first(10) }, write)
      ensure
        write.close
      end

      write.close
      result = read.read
      Process.waitpid(pid)
      read.close

      if result.size.positive?
        data = Marshal.load(result) # rubocop:disable Security/MarshalLoad
        exception = data[:error_class]&.safe_constantize&.new(data[:error])
        exception&.set_backtrace(data[:backtrace])
        raise exception.presence || 'unkown error'
      end

      if insert_ids.present? || delete_ids.present? ? ca.update(updated_at: Time.zone.now) : true
        ActionCable.server.broadcast('classification_update', { type: 'unlock', id: })
      else
        ActionCable.server.broadcast('classification_update', { type: 'error', id: })
      end
    end

    private

    def notify_with_lock
      ActionCable.server.broadcast('classification_update', { type: 'lock', id: arguments[0] })
    end
  end
end
