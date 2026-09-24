# frozen_string_literal: true

module DataCycleCore
  # The allocator the container images run on (LD_PRELOAD in datacycle-docker's build/ruby/Dockerfile).
  # On a macOS host or a project still on an older base image jemalloc is absent, and every method
  # here answers for that.
  module Jemalloc
    class << self
      # Whether jemalloc is the allocator of this process. +mallctl+ is its own control entry point
      # and has no glibc counterpart, which is what makes it the thing to ask: glibc's +mallopt+ and
      # +malloc_trim+ resolve either way, because glibc stays linked into a process that preloads
      # jemalloc and merely stops being its allocator.
      # @return [Boolean]
      def available?
        !mallctl.nil?
      end

      # Whether jemalloc's decay purge is running in this process, which is what hands the pages of a
      # finished job back to the OS. Measured on the app image, freeing 500 MB and then idling:
      # 251 MB retained with it, 519 MB without. Nothing in the app asks; this is how
      # +test/models/jemalloc_test.rb+ observes that config/initializers/jemalloc.rb's +after_fork+
      # hook ran in the child, and how a console check asks the same question.
      # @return [Boolean]
      def background_thread?
        return false if mallctl.nil?

        value = Fiddle::Pointer.malloc(1, Fiddle::RUBY_FREE)
        length = Fiddle::Pointer.malloc(Fiddle::SIZEOF_SIZE_T, Fiddle::RUBY_FREE)
        length[0, Fiddle::SIZEOF_SIZE_T] = [1].pack('J')

        mallctl.call('background_thread', value, length, nil, 0).zero? && value[0] == 1
      end

      # Turns the background thread back on, and does nothing under any other allocator. jemalloc
      # turns it off in every child of a fork(2) regardless of what the parent had, as its
      # +background_thread+ mallctl documents, and every process that does the work here is such a
      # child: SolidQueue forks a worker per config/queue.yml entry, puma forks its workers under
      # preload_app!, and the importers fork per page.
      # @return [Integer, nil] mallctl's status, 0 on success; nil under any other allocator
      def enable_background_thread!
        mallctl&.call('background_thread', nil, nil, [1].pack('C'), 1)
      end

      private

      # @return [Fiddle::Function, nil] nil when this process does not run on jemalloc
      def mallctl
        return @mallctl if defined?(@mallctl)

        @mallctl = begin
          require 'fiddle'

          Fiddle::Function.new(
            Fiddle.dlopen(nil)['mallctl'],
            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
            Fiddle::TYPE_INT
          )
        rescue LoadError, Fiddle::DLError
          nil
        end
      end
    end
  end
end
