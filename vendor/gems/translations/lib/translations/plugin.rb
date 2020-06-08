# frozen_string_literal: true

module Translations
  module Plugin
    def initialize_hook(&block)
      define_method :initialize do |*names, **options|
        super(*names, **options)
        class_exec(*names, **options, &block)
      end
    end

    def included_hook(&block)
      define_method :included do |klass|
        super(klass).tap do |backend_class|
          class_exec(klass, backend_class, &block)
        end
      end
    end
  end
end
