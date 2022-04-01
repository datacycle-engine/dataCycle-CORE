# frozen_string_literal: true

module DataCycleCore
  class ProgressBarService
    def initialize(total_count = 0, title: nil)
      @index = 0
      @title = title
      @total_count = total_count
      @interval ||= [@total_count / 100.0, 1.0].max.round(0)
    end

    def inc
      if @index >= @total_count
        print "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\n"
        return @index += 1
      end
      if (@index % @interval).zero?
        fraction = (((@index * 1.0) / @total_count) * 100.0).round(0)
        fraction = 100 if fraction > 100
        print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
      end
      @index += 1
    end

    def title
      return if @title.nil?
      puts @title
    end

    def finish
      puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
    end

    def self.for_shell(total_count = 0, title: nil)
      pb = new(total_count, title: title)
      pb.title
      yield(pb)
      pb.finish
    end
  end
end
