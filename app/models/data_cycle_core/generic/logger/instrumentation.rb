# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Logger
      class Instrumentation
        def initialize(kind)
          @kind = kind
        end

        def preparing_phase(label)
          info_instrument(message: "Preparing  #{label} ...")
        end

        def phase_started(label, total = nil)
          message = [@kind.capitalize.ljust(11), label.to_s]
          message.push(" (#{total} items)") if total
          message.push(' ... [STARTED]')

          info_instrument(message: message.join)
        end

        def batch_downloaded(count, start_time, current_time, prev_time)
          step_time = DataCycleCore::Generic::GenericObject.format_float((current_time - start_time), 6, 3)
          step_delta = DataCycleCore::Generic::GenericObject.format_float((current_time - prev_time), 6, 3)
          message = "Downloaded #{count.to_s.rjust(7)} items in #{step_time}s, ðt: #{step_delta}s"

          info_instrument(message:)
        end

        def item_processed(*)
          # dont log every single item
          # @log.info " -> \"#{title} (\##{id})\" #{@kind}ed (#{num} of #{total || '?'})"
        end

        def step_failed(exception, external_system, step_label, channel = 'download_failed.datacycle')
          error_instrument(exception:, external_system:, step_label:, channel:, namespace: 'background')
        end

        def error(title, id, data, error)
          if title && id
            err = "Error #{@kind}ing \"#{title} (\##{id})\": #{error}"
          elsif title
            err =  "Error #{@kind}ing \"#{title}\": #{error}"
          elsif id
            err =  "Error #{@kind}ing \"\##{id}\": #{error}"
          else
            err =  "Error: #{error}"
          end

          error_instrument(message: err)

          if data
            data_string = JSON.pretty_generate(data).split("\n")
            data_string_size = data_string.size
            data_string = data_string.first(20)
            data_string += ["... MORE: + #{data_string_size - 20} lines \n"] if data_string_size > 20
            error_instrument(message: "  DATA: #{data_string.join("\n  ")}")
          end

          error_instrument(message: error.full_message) if error.respond_to?(:full_message)
        end

        def info(title, id = nil)
          message = title
          message += " | #{id}" if id

          info_instrument(message:)
        end

        def debug(title, id, data)
          debug_instrument(message: "#{title} | #{id} | #{JSON.pretty_generate(data).gsub("\n", "\n  ")}")
        end

        def phase_finished(label, total)
          message = "#{(@kind.capitalize + 'ed').ljust(11)}#{label} ... [DONE] (#{total.to_i} items)"

          info_instrument(message:)
        end

        private

        def info_instrument(**keyword_args)
          log_instrument(severity: 'info', **keyword_args)
        end

        def debug_instrument(**keyword_args)
          log_instrument(severity: 'debug', **keyword_args)
        end

        def warning_instrument(**keyword_args)
          log_instrument(severity: 'warning', **keyword_args)
        end

        def error_instrument(**keyword_args)
          log_instrument(severity: 'error', **keyword_args)
        end

        def log_instrument(
          message: '',
          severity: 'debug',
          external_system: nil,
          step_label: '',
          exception: nil,
          namespace: 'instrumentation_logging',
          channel: 'instrumentation_logging.datacycle',
          item_id: nil
        )
          ActiveSupport::Notifications.instrument channel, {
            message:,
            namespace:,
            external_system:,
            step_label:,
            type: @kind,
            severity:,
            exception:,
            item_id:
          }
        end
      end
    end
  end
end
