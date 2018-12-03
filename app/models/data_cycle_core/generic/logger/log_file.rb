# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Logger
      class LogFile
        def initialize(kind)
          @kind = kind
          @log = ::Logger.new("./log/#{kind}.log")
        end

        def preparing_phase(label)
          @log.info "Preparing  #{label} ..."
        end

        def phase_started(label, total = nil)
          @log.info "#{@kind.capitalize}   #{label.to_s.tr('/_/', ' ')} ..." if total.nil?
          @log.info "#{@kind.capitalize}   #{label.to_s.tr('/_/', ' ')} (#{total} items) ..." if total
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
          @log.error "  DATA: #{JSON.pretty_generate(data).gsub(/\n/, "\n  ")}" if data
        end

        def info(title, id)
          id.blank? ? @log.info("INFO: #{title}") : @log.info("INFO: #{title} | #{id}")
        end

        def debug(title, id, data)
          @log.debug "#{title} | #{id} | #{JSON.pretty_generate(data).gsub(/\n/, "\n  ")}"
        end

        def phase_finished(label, total)
          @log.info "#{@kind.capitalize}ed #{label.to_s.tr('/_/', ' ')} (#{total} items) ... [DONE]"
        end

        def close
          @log.close
        end
      end
    end
  end
end
