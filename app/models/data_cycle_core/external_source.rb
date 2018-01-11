module DataCycleCore
  class ExternalSource < ApplicationRecord
    has_many :use_cases

    def download(options = {}, &block)
      full_options = options.merge({ download: config['download_config'].symbolize_keys })
      if config['download'].starts_with?('::') || config['download'].starts_with?('DataCycleCore::')
        config['download'].constantize.new(id).download(full_options, &block)
      else
        "DataCycleCore::#{config['download']}".constantize.new(id).download(full_options, &block)
      end
    end

    def import(options = {}, &bock)
      full_options = options.merge({ import: config['import_config'].symbolize_keys })
      if config['import'].starts_with?('::') || config['import'].starts_with?('DataCycleCore::')
        config['import'].constantize.new(id).import(full_options, &bock)
      else
        "DataCycleCore::#{config['import']}".constantize.new(id).import(full_options, &bock)
      end
    end
  end
end
