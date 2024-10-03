# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Logger
      class Instrumentation
        def initialize(kind)
          @kind = kind
          @kind_short = "[#{kind.to_s[0].upcase}]"
        end

        def preparing_phase(label)
          info_instrument(message: "Preparing  #{label} ...")
        end

        def phase_started(label, total = nil)
          message = [@kind_short, label.to_s]
          message.push("(#{total} items)") if total
          message.push('... [STARTED]')

          info_instrument(message: message.join(' '))
        end

        def phase_partial(label, count, times = nil, id = nil)
          message = [
            @kind_short,
            label.to_s,
            count.to_s.prepend(' ').rjust(7, '.'),
            'items'
          ].join(' ')

          if times.present?
            step_time = DataCycleCore::Generic::GenericObject.format_float((times[-1] - times[0]), 6, 3)
            step_delta = DataCycleCore::Generic::GenericObject.format_float((times[-1] - times[-2]), 6, 3)
            message += " in #{step_time}s, ðt: #{step_delta}s"
          end

          message += " | #{id}" if id

          info_instrument(message:)
        end

        def info(label, text, id = nil)
          message = [@kind_short, label.to_s, text.to_s].join(' ')
          message += " | #{id}" if id

          info_instrument(message:)
        end

        def warning(label, text, id = nil)
          message = [@kind_short, label.to_s, text.to_s].join(' ')
          message += " | #{id}" if id

          warning_instrument(message:)
        end

        def phase_finished(label, total = nil, duration = nil)
          message = [@kind_short, label.to_s, '...', '[FINISHED]'].join(' ')
          additional_message = []
          additional_message.push("#{total.to_i} #{total.to_i == 1 ? 'item' : 'items'}") if total.respond_to?(:to_i)
          additional_message.push("in #{duration.to_f.round(3)}s") if duration.respond_to?(:to_f)
          message += " (#{additional_message.join(' ')})" if additional_message.present?

          info_instrument(message:)
        end

        def item_processed(*)
          # dont log every single item
          # @log.info " -> \"#{title} (\##{id})\" #{@kind}ed (#{num} of #{total || '?'})"
        end

        def phase_failed(exception, external_system, step_label, channel = 'download_failed.datacycle')
          error_instrument(exception:, external_system:, step_label:, channel:, namespace: 'background')
        end

        def validation_error(label, data, error_text)
          text = [@kind_short, label.to_s]
          text.push(error_text.to_s) if error_text.present?

          if data.present?
            data_string = JSON.pretty_generate(data).split("\n")
            data_string_size = data_string.size
            data_string = data_string.first(20)
            data_string += ["... MORE: + #{data_string_size - 20} lines \n"] if data_string_size > 20
            text.push("| DATA: #{data_string.join("\n#{' ' * 50}")}")
          end

          error_instrument(message: text.join(' '))
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

        def debug(title, id, data)
          debug_instrument(message: "#{title} | #{id} | #{JSON.pretty_generate(data).gsub("\n", "\n  ")}")
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
