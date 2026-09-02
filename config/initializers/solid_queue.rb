# frozen_string_literal: true

# A SolidQueue worker runs `threads` jobs at once in a single process, and all of them draw on the
# one connection pool that process has. Publish that number so anything sizing a thread pool per job
# can divide by it; the supervisor forks a process per worker, so each one records its own count.
#
# Nothing else needs the hook: the web process, rake tasks, the scheduler and the dispatcher all run
# one job (or none) at a time, which is the default set in +DataCycleCore.concurrent_job_threads+.
#
# The value is a process-global, which is correct only because the supervisor forks — the mode
# bin/jobs runs in. Under SolidQueue's AsyncSupervisor (the Puma plugin) the workers are threads of
# the web process, and this would overwrite that process's own count. Do not enable that mode
# without giving the counter a narrower scope first.
SolidQueue.on_worker_start do |worker|
  DataCycleCore.concurrent_job_threads = worker.pool.size
end
