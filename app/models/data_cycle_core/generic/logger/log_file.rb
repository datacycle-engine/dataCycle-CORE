# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Logger
      class LogFile
        def initialize(kind)
          @kind = kind
          @log = ::Logger.new("./log/#{kind}.log")
          @log_data_lines = 20
        end

        def preparing_phase(label)
          @log.info "Preparing  #{label} ..."
        end

        def phase_started(label, total = nil)
          @log.info [@kind.capitalize.ljust(11), "#{label.to_s.tr('/_/', ' ')} ..."].join if total.nil?
          @log.info [@kind.capitalize.ljust(11), "#{label.to_s.tr('/_/', ' ')} (#{total} items) ..."].join if total
        end

        def item_processed(title, id, num, total)
          # @log.info " -> \"#{title} (\##{id})\" #{@kind}ed (#{num} of #{total || '?'})"
        end

        def error(title, id, data, error)
          if title && id
            @log.error "Error #{@kind}ing \"#{title} (\##{id})\": #{error}"
          elsif title
            @log.error "Error #{@kind}ing \"#{title}\": #{error}"
          elsif id
            @log.error "Error #{@kind}ing \"\##{id}\": #{error}"
          else
            @log.error "Error: #{error}"
          end

          if data
            data_string = JSON.pretty_generate(data).split("\n")
            data_string_size = data_string.size
            data_string = data_string.first(@log_data_lines)
            data_string += ["... MORE: + #{data_string_size - 20} lines \n"] if data_string_size > @log_data_lines
            @log.error "  DATA: #{data_string.join("\n  ")}"
          end
          @log.error error.full_message if error.respond_to?(:full_message)
        end

        def info(title, id = nil)
          id.blank? ? @log.info(title) : @log.info("#{title} | #{id}")
        end

        def debug(title, id, data)
          @log.debug "#{title} | #{id} | #{JSON.pretty_generate(data).gsub("\n", "\n  ")}"
        end

        def phase_finished(label, total)
          @log.info ["#{@kind.capitalize}ed".ljust(11), "#{label.to_s.tr('/_/', ' ')} (#{total} items) ... [DONE]"].join
        end

        def close
          @log.close
        end
      end
    end
  end
end
