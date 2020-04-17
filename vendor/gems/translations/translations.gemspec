# frozen_string_literal: true

lib = File.expand_path('./lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'translations/version'

Gem::Specification.new do |spec|
  spec.name          = 'translations'
  spec.version       = Translations::VERSION
  spec.authors       = ['Martin Oehzelt']
  spec.email         = ['oehzelt@datacycle.at']

  spec.required_ruby_version = '~> 2.7.1'

  spec.summary       = 'Ruby translation framework'
  spec.description   = 'Stores and retrieves localized data through attributes on a Ruby class, with support for storing data in jsonb fields or a translation table.'

  spec.homepage      = 'https://git.pixelpoint.biz/data-cycle'
  spec.license       = 'MIT'

  spec.files         = Dir['{lib/**/*,[A-Z]*}']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'i18n', '>= 0.6.10', '< 2'
  spec.add_dependency 'request_store', '~> 1.0'

  spec.add_development_dependency 'database_cleaner', '~> 1.5', '>= 1.5.3'
  spec.add_development_dependency 'rake', '~> 12', '>= 12.2.1'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'yard', '~> 0.9.0'
end
