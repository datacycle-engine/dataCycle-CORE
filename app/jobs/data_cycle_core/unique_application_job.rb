# frozen_string_literal: true

module DataCycleCore
  # A job that must not pile up per concurrency key: further enqueues are dropped instead of queueing
  # up work that the one already waiting is about to do anyway. This is the +clear_previous_jobs+
  # behaviour of the delayed_job era — which kept one pending job per reference and never touched a
  # running one — expressed through SolidQueue's concurrency controls. How many are outstanding at
  # once follows the conflict mode: one running plus one waiting for +:block+, exactly one for
  # +:discard+ (see +abort_if_queued+).
  #
  # Uniqueness is derived entirely from the concurrency key, so a subclass has to declare
  # +limits_concurrency+. Without it there is nothing to be unique by and inheriting from this class
  # would quietly buy nothing, which is why the missing declaration is an error rather than a
  # degraded mode — the +delayed_reference_id+ it replaces raised for the same reason.
  class UniqueApplicationJob < ApplicationJob
    before_enqueue :abort_if_queued

    # The two conflict modes leave different traces behind, so what counts as "already there"
    # depends on which one the subclass declared:
    #
    # * +:block+ (the default) — the first job takes the semaphore and becomes ready, the second is
    #   blocked on it. A third would only add work the blocked one is about to do anyway, so abort
    #   as soon as a blocked duplicate exists.
    # * +:discard+ — SolidQueue destroys the losing job at dispatch, so there is never a blocked row
    #   to recognise, and it only does so for as long as the semaphore is held. Ask the jobs table
    #   instead: that closes the window in which the lock has lapsed, and it lets +perform_later+
    #   answer +false+ rather than hand back a row that has already been deleted again.
    # @return [void]
    def abort_if_queued
      raise "#{self.class.name} inherits #{UniqueApplicationJob.name} but declares no limits_concurrency to be unique by" if concurrency_key.nil?

      throw :abort if concurrency_on_conflict.to_s == 'discard' ? duplicate_pending? : duplicate_queued?
    end
  end
end
