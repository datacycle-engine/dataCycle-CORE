# frozen_string_literal: true

module Translations
  module Translates
    [:accessor, :reader, :writer].each do |method|
      class_eval <<-EOM, __FILE__, __LINE__ + 1
        def translation_#{method}(*args, **options, &block)
          attributes = Translations.config.attributes_class.new(*args, method: :#{method}, **options)
          attributes.backend.instance_eval(&block) if block_given?
          include attributes
        end
      EOM
    end
  end
end
