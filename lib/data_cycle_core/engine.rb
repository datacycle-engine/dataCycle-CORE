module DataCycleCore
  class Engine < ::Rails::Engine
    isolate_namespace DataCycleCore

    require 'pg'
    require 'activerecord-postgis-adapter'
    require 'rgeo'
    require 'mongoid'

    require 'faraday'
    require 'logging'

  end
end
