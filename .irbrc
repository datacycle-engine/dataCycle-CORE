# frozen_string_literal: true

IRB.conf[:SAVE_HISTORY] = 100
IRB.conf[:HISTORY_FILE] = File.join('.irb-history')
IRB.conf[:AUTO_INDENT] = true
IRB.conf[:BACK_TRACE_LIMIT] = 100

Rails.backtrace_cleaner.remove_silencers!
