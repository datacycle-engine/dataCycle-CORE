# frozen_string_literal: true

module DataCycleCore
  class ClassificationMappingJob < ApplicationJob
    before_enqueue :notify_with_lock
    queue_with_priority 10
    limits_concurrency key: ->(*args) { args[0] }, duration: 10.minutes

    def perform(id, to_insert = [], to_delete = [])
      ca = DataCycleCore::ClassificationAlias.find_by(id:)

      return if ca.nil?

      insert_ids = Array.wrap(to_insert) - ca.classification_ids
      delete_ids = Array.wrap(to_delete).intersection(ca.classification_ids)

      # Mapping rebuilds can touch a large number of paths/contents; in production the work runs
      # in a forked process to keep its memory and long-running statements out of the worker. In
      # test the fork would commit past the transactional rollback, so run it in-process there
      # (mirrors the Rails.env.test? guard in generic/common/import_functions).
      if Rails.env.test?
        apply_mapping_changes(ca, insert_ids, delete_ids)
      else
        run_mapping_changes_in_fork(ca, insert_ids, delete_ids)
      end

      if insert_ids.present? || delete_ids.present? ? ca.update(updated_at: Time.zone.now) : true
        ActionCable.server.broadcast('classification_update', { type: 'unlock', id: })
      else
        ActionCable.server.broadcast('classification_update', { type: 'error', id: })
      end
    end

    private

    def apply_mapping_changes(ca, insert_ids, delete_ids)
      ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

        ca.classification_groups.insert_all(insert_ids.map { |cid| { classification_id: cid } }, unique_by: :classification_groups_ca_id_c_id_uq_idx, returning: false) if insert_ids.present?
        ca.classification_groups.where(classification_id: delete_ids).delete_all if delete_ids.present?

        # one job per side effect (search / webhooks / computed recompute) for the union of all
        # affected contents — see ClassificationAlias#classifications_changed
        ca.send(:classifications_changed, insert_ids + delete_ids)

        ca.touch
      end
    end

    def run_mapping_changes_in_fork(ca, insert_ids, delete_ids)
      read, write = IO.pipe
      pid = Process.fork do
        read.close
        apply_mapping_changes(ca, insert_ids, delete_ids)
      rescue StandardError => e
        Marshal.dump({ error_class: e.class.name, error: e.to_s, backtrace: e.backtrace.first(10) }, write)
      ensure
        write.close
      end

      write.close
      result = read.read
      Process.waitpid(pid)
      read.close

      return if result.empty?

      data = Marshal.load(result) # rubocop:disable Security/MarshalLoad
      exception = DataCycleCore::ErrorService.rebuild(data[:error_class], data[:error], data[:backtrace])
      raise exception || 'unkown error'
    end

    def notify_with_lock
      ActionCable.server.broadcast('classification_update', { type: 'lock', id: arguments[0] })
    end
  end
end
