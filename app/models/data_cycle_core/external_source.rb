module DataCycleCore
  class ExternalSource < ApplicationRecord
    has_many :places
    has_many :classifications_regions

    has_many :use_cases

    def download(options = {}, &block)
      if config['download'].starts_with?('::') || config['download'].starts_with?('DataCycleCore::')
        "#{config['download']}".constantize.new(id).download(options, &block)
      else
        "DataCycleCore::#{config['download']}".constantize.new(id).download(options, &block)
      end
    end

    def import(options = {})
      if config['import'].starts_with?('::') || config['import'].starts_with?('DataCycleCore::')
        "#{config['import']}".constantize.new(id).import(options)
      else
        "DataCycleCore::#{config['import']}".constantize.new(id).import(options)
      end
    end
  end
end
