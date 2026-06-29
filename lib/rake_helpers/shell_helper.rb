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
  end
end
