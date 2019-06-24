# frozen_string_literal: true

module DataCycleCore
  class ProgressBarService
    def initialize(total_count = 0)
      @index = 0
      @total_count = total_count
    end

    def inc
      if @total_count > 49
        if (@index % 500).zero?
          fraction = (@index / (@total_count / 100.0)).round(0)
          fraction = 100 if fraction > 100
          print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
        end
      else
        fraction = (((@index * 1.0) / @total_count) * 100.0).round(0)
        fraction = 100 if fraction > 100
        print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
      end
      @index += 1
    end

    def finish
      puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
    end

    def self.for_shell(total_count = 0)
      pb = new(total_count)
      yield(pb)
      pb.finish
    end
  end
end
