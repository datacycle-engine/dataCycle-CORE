# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# added ?
# require 'bootsnap/setup' # Speed up boot time by caching expensive operations.

# added
$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__)
