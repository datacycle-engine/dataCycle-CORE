# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Logger
      class Console
        def initialize(kind)
          @kind = kind
        end

        def preparing_phase(label)
          puts "Preparing  #{label.to_s.tr('/_/', ' ')} ..."
        end

        def phase_started(label, total = nil)
          puts [@kind.capitalize.ljust(10), "#{label.to_s.tr('/_/', ' ')} ..."].join if total.nil?
          puts [@kind.capitalize.ljust(10), "#{label.to_s.tr('/_/', ' ')} (#{total} items) ..."].join if total
        end

        def item_processed(title, id, num, total)
          # puts " -> \"#{title} (\##{id})\" #{@kind}ed (#{num} of #{total || '?'})"
        end

        def error(title, id, data, error)
          if title && id
            puts "Error #{@kind}ing \"#{title} (\##{id})\": #{error}"
          elsif title
            puts "Error #{@kind}ing \"#{title}\": #{error}"
          elsif id
            puts "Error #{@kind}ing \"\##{id}\": #{error}"
          else
            puts "Error: #{error}"
          end
          puts "  DATA: #{JSON.pretty_generate(data).gsub(/\n/, "\n  ")}" if data
        end

        def info(title, id)
          id.blank? ? @log.info("INFO: #{title}") : @log.info("INFO: #{title} | #{id}")
        end

        def phase_finished(label, total)
          puts [(@kind.capitalize + 'ed').ljust(10), "#{label.to_s.tr('/_/', ' ')} (#{total} items) ... [DONE]"].join
        end
      end
    end
  end
end
