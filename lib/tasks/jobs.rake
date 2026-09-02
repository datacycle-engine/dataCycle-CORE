# frozen_string_literal: true

namespace :jobs do
  # Kept as the local entry point (`rails jobs:work`) from the delayed_job era; the containers run
  # bin/jobs directly. Recurring tasks are skipped because cron lives in rufus (bin/scheduler and
  # DataCycleCore::RufusYamlScheduler), not in SolidQueue's scheduler — no app ships a
  # config/recurring.yml, and none should without moving its schedule over first.
  desc 'start job worker'
  task work: :environment do
    ENV['SOLID_QUEUE_SKIP_RECURRING'] = 'true'
    # blocks until the supervisor shuts down, so there is nothing to reenable afterwards
    Rake::Task['solid_queue:start'].invoke
  end
end
