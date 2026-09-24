# frozen_string_literal: true

# Every process in this app that allocates in earnest is a forked child (a SolidQueue worker, a puma
# worker, an importer's per-page fork), and jemalloc hands each of them its background thread turned
# off. Turning it back on is what makes its decay purge apply where the memory actually is; see
# +DataCycleCore::Jemalloc.enable_background_thread!+ for the measurement.
#
# ForkTracker covers all three at once, and a forking site added later needs nothing. Registered
# whatever the allocator is, because asking +DataCycleCore::Jemalloc+ here would resolve an
# autoloaded constant before the autoloaders are set up; under glibc the call does nothing.
ActiveSupport::ForkTracker.after_fork { DataCycleCore::Jemalloc.enable_background_thread! }
