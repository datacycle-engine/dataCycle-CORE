# config/initializers/dj_rails5_patches.rb
# RAILS 5 patches for delayed_job
# TODO: REMOVE WHEN upstream is updated

module DelayedWorkerPatches
  def reload!
    return unless self.class.reload_app?
    if defined?(ActiveSupport::Reloader)
      Rails.application.reloader.reload!
    else
      ActionDispatch::Reloader.cleanup!
      ActionDispatch::Reloader.prepare!
    end
  end
end

module Delayed
  class Worker
    prepend DelayedWorkerPatches
  end
end
