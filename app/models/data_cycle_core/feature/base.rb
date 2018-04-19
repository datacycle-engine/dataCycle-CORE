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

        def present?(content)
          enabled? && content&.schema&.dig('features', name.demodulize.underscore).present?
        end

        def attribute_keys(content)
          enabled? && present?(content) ? content&.schema&.dig('features', name.demodulize.underscore) : []
        end
      end
    end
  end
end
