# frozen_string_literal: true

module Translations
  module Util
    VALID_CONSTANT_NAME_REGEXP = /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/.freeze

    def self.included(klass)
      klass.extend(self)
    end

    def camelize(str)
      call_or_yield str do
        str.to_s.sub(/^[a-z\d]*/) { $&.capitalize }.gsub(/(?:_|(\/))([a-z\d]*)/) { "#{$1}#{$2.capitalize}" }.gsub('/', '::') # rubocop:disable Style/RegexpLiteral, Style/PerlBackrefs
      end
    end

    def constantize(str)
      str = str.to_s
      call_or_yield str do
        raise(NameError, "#{s.inspect} is not a valid constant name!") unless (m = VALID_CONSTANT_NAME_REGEXP.match(str))
        Object.module_eval("::#{m[1]}", __FILE__, __LINE__)
      end
    end

    def singularize(str)
      call_or_yield str do
        str.to_s.delete_suffix('s')
      end
    end

    def demodulize(str)
      call_or_yield str do
        str.to_s.gsub(/^.*::/, '')
      end
    end

    def foreign_key(str)
      call_or_yield str do
        "#{underscore(demodulize(str))}_id"
      end
    end

    def underscore(str)
      call_or_yield str do
        str.to_s.gsub(/::/, '/').gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2').tr('-', '_').downcase
      end
    end

    def present?(object)
      !blank?(object)
    end

    def blank?(object)
      return true if object.nil?
      object.respond_to?(:empty?) ? !!object.empty? : !object # rubocop:disable Style/DoubleNegation
    end

    def presence(object)
      object if present?(object)
    end

    private

    # Calls caller method on object if defined, otherwise yields to block
    def call_or_yield(object)
      caller_method = caller_locations(1, 1)[0].label
      if object.respond_to?(caller_method)
        object.public_send(caller_method)
      else
        yield
      end
    end

    extend self
  end
end
