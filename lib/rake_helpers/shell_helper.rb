# frozen_string_literal: true

class ShellHelper
  class << self
    def zsh?
      ENV['SHELL']&.split('/')&.last == 'zsh'
    end

    def error(msg)
      puts msg # rubocop:disable Rails/Output
      exit(-1) # rubocop:disable Rails/Exit
    end

    def prompt(*)
      print(*) # rubocop:disable Rails/Output
      $stdin.gets.strip
    end

    def progress_bar(total_items, index, interval = nil)
      if index >= total_items
        print "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\n" # rubocop:disable Rails/Output
        return
      end
      interval ||= [total_items / 100.0, 1.0].max.round(0)
      return unless (index % interval).zero?
      fraction = (((index * 1.0) / total_items) * 100.0).round(0)
      fraction = 100 if fraction > 100
      print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r" # rubocop:disable Rails/Output
    end
  end
end
