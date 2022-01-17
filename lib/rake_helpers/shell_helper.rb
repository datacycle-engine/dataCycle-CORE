# frozen_string_literal: true

class ShellHelper
  class << self
    def zsh?
      ENV['SHELL']&.split('/')&.last == 'zsh'
    end

    def error(msg)
      puts msg
      exit(-1)
    end

    def prompt(*args)
      print(*args)
      STDIN.gets.strip
    end

    def progress_bar(total_items, index, interval = nil)
      if index >= total_items
        print "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\n"
        return
      end
      interval ||= [total_items / 100.0, 1.0].max.round(0)
      return unless (index % interval).zero?
      fraction = (((index * 1.0) / total_items) * 100.0).round(0)
      fraction = 100 if fraction > 100
      print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
    end
  end
end
