# frozen_string_literal: true

# A SolidQueue worker runs `threads` jobs at once in a single process, and all of them draw on the
# one connection pool that process has. Publish that number so anything sizing a thread pool per job
# can divide by it; the supervisor forks a process per worker, so each one records its own count.
#
# The hook is also where +DataCycleCore::WorkerMemoryGuard+ starts watching, because a forked worker
# is the one process here that something replaces when it exits. Nothing else needs either: the web
# process, rake tasks, the scheduler and the dispatcher all run one job (or none) at a time, the
# default set in +DataCycleCore.concurrent_job_threads+, and none of them comes back if it ends.
#
# Both are process-globals, which is correct only because bin/jobs runs the supervisor in fork mode.
# Under SolidQueue's AsyncSupervisor (SOLID_QUEUE_SUPERVISOR_MODE=async, or the Puma plugin's
# `solid_queue_mode :async`) the workers are threads of the web process: +WorkerMemoryGuard.forked?+
# declines such a worker itself, but the count would overwrite that process' own, so do not enable
# that mode without giving the count a scope of its own.
SolidQueue.on_worker_start do |worker|
  DataCycleCore.concurrent_job_threads = worker.pool.size
  DataCycleCore::WorkerMemoryGuard.supervise(worker)
end
