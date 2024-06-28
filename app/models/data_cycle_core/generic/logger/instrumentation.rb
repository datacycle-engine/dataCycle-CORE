# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Logger
      class Instrumentation
        def initialize(kind)
          @kind = kind
          # @log = ::Logger.new("./log/#{kind}_instrumentation.log")
          @log_data_lines = 20
        end

        def preparing_phase(label)
          text = "Preparing  #{label} ..."
          info_instrument(text)
        end

        def phase_started(label, total = nil)
          info_instrument [@kind.capitalize.ljust(11), "#{label.to_s.tr('/_/', ' ')} ..."].join if total.nil?
          info_instrument [@kind.capitalize.ljust(11), "#{label.to_s.tr('/_/', ' ')} (#{total} items) ..."].join if total
        end

        def item_processed(title, id, num, total)
          # @log.info " -> \"#{title} (\##{id})\" #{@kind}ed (#{num} of #{total || '?'})"
        end

        def error(title, id, data, error, instrumentation_payload)
          if title && id
            err = "Error #{@kind}ing \"#{title} (\##{id})\": #{error}"
          elsif title
            err =  "Error #{@kind}ing \"#{title}\": #{error}"
          elsif id
            err =  "Error #{@kind}ing \"\##{id}\": #{error}"
          else
            err =  "Error: #{error}"
          end

          error_instrument(err)

          if data
            data_string = JSON.pretty_generate(data).split("\n")
            data_string_size = data_string.size
            data_string = data_string.first(@log_data_lines)
            data_string += ["... MORE: + #{data_string_size - 20} lines \n"] if data_string_size > @log_data_lines
            error_instrument "  DATA: #{data_string.join("\n  ")}"
          end
          error_instrument error.full_message, instrumentation_payload if error.respond_to?(:full_message)
        end

        def info(title, id = nil)
          id.blank? ? info_instrument(title) : info_instrument("#{title} | #{id}")
        end

        def debug(title, id, data)
          debug_instrument "#{title} | #{id} | #{JSON.pretty_generate(data).gsub("\n", "\n  ")}"
        end

        def phase_finished(label, total)
          info_instrument [(@kind.capitalize + 'ed').ljust(11), "#{label.to_s.tr('/_/', ' ')} (#{total} items) ... [DONE]"].join
        end

        def close
        end

        def log_instrument(message, severity = 'debug', external_system_name = '', execution_step = '')
          ActiveSupport::Notifications.instrument 'instrumentation_logging.datacycle', {
            message:,
            namespace: 'instrumentation_logging',
            external_system: external_system_name,
            execution_step:,
            type: @kind,
            severity:,
            appsignal_triggered: false
          }
        end

        def info_instrument(message, external_system_name = '', execution_step = '')
          log_instrument(message, 'info', external_system_name, execution_step)
        end

        def debug_instrument(message, external_system_name = '', execution_step = '')
          log_instrument(message, 'debug', external_system_name, execution_step)
        end

        def warning_instrument(message, external_system_name = '', execution_step = '')
          log_instrument(message, 'warning', external_system_name, execution_step)
        end

        def error_instrument(message, external_system_name = '', execution_step = '')
          log_instrument(message, 'error', external_system_name, execution_step)
        end

        def error_detailed(options = {message => nil, exception => nil, execution_step => nil, external_system => nil, item => nil})
          message = options[:message] || options[:exception].message
          out = ''
          out += (@kind.present? ? "#{@kind} " : '')
          out += (options[:execution_step].present? ? "#{options[:execution_step]} " : '')
          out += (options[:external_system].present? ? "from '#{options[:external_system]}' " : '')
          out += handle_data_item(options[:item])
          out += handle_exception(options[:exception])
          out += (message.present? ? "\nError: #{message}" : '')
          out
        end

        private

        def handle_exception(exception)
          return '' if exception.blank?

          exception_message = exception.message
          exception_class = exception.class
          backtrace = exception.backtrace.join("\n")
          "with exception '#{exception_message}' (#{exception_class}) \nBacktrace:\n#{backtrace}\n"
        end

        def handle_data_item(item)
          return '' if item.blank?

          item_handling = "\nError in item "
          item_handling += (item[:title].present? ? "'#{item[:title]}' " : '')
          item_handling += (item[:id].present? ? "\nwith ID '#{item[:id]}' " : '')
          item_handling += (item[:title].blank? && item[:id].blank? ? "\nwith unknown name/ID " : '')
          item_handling + (item[:data].present? ? "\nwith data:\n#{JSON.pretty_generate(item[:data])&.split("\n")}" : '')
        end
      end
    end
  end
end

#
# logging_options: {
#   print_logs: is_instrumentation_log,
#   logging_message: logging.error_detailed({
#                                             exception: e,
#                                             external_system: download_object.external_source.name.to_s,
#                                             execution_step: "#{endpoint_method} [#{locale}]",
#                                             item: {raw_data: item.presence}
#                                           })
# }
