module DataCycleCore
  module Feature
    class Base
      attr_reader :content

      def initialize(content: nil)
        @content = content
      end

      class << self
        def enabled?
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym, :enabled)
        end

        def attribute_keys(content)
          content&.schema&.dig('features', name.demodulize.underscore)
        end

        def available?(content)
          attribute_keys(content).present?
        end

        def allowed?(content)
          enabled? && available?(content)
        end

        def allowed_attribute_keys(content)
          allowed?(content) ? attribute_keys(content) : []
        end

        def includes_attribute_key(content, key)
          (key.scan(/\[(.*?)\]/).flatten & attribute_keys(content)).size.positive?
        end
      end
    end
  end
end
