# frozen_string_literal: true

module DataCycleCore
  module JobExtensions
    module Callbacks
      extend ActiveSupport::Concern

      included do
        attr_accessor :last_error

        define_callbacks :success, :error, :failure
        after_perform ->(job) { job.run_callbacks :success }

        rescue_from StandardError do |exception|
          @last_error = exception

          if executions < self.class::ATTEMPTS
            ActiveSupport::Notifications.instrument 'exception.datacycle', exception
            run_callbacks :error
            retry_job wait: determine_delay(seconds_or_duration_or_algorithm: self.class::WAIT, executions:), priority: priority + 1, error: exception
          else
            run_callbacks :failure
            raise exception
          end
        end
      end

      class_methods do
        def after_success(*filters, &)
          set_callback(:success, :after, *filters, &)
        end

        def after_error(*filters, &)
          set_callback(:error, :after, *filters, &)
        end

        def after_failure(*filters, &)
          set_callback(:failure, :after, *filters, &)
        end
      end
    end
  end
end
