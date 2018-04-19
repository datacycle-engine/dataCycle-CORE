module DataCycleCore
  module Feature
    class Base
      attr_reader :content

      def initialize(content: nil)
        @content = content
      end

      def enabled?
        DataCycleCore.features.dig(self.class.name.demodulize.underscore.to_sym, :enabled)
      end

      def present?
        @content&.schema&.dig('features', self.class.name.demodulize.underscore).present?
      end

      def attribute_keys
        enabled? && present? ? @content&.schema&.dig('features', self.class.name.demodulize.underscore) : []
      end
    end
  end
end
