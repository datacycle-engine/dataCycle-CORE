module DataCycleCore
  module OutdoorActive
    module ImageAttributeTransformation
      def external_key
        self['id'].try(:strip)
      end

      def headline
        self['title'].try(:strip)
      end

      def content_url
        "http://img.oastatic.com/img/#{self['id']}/.jpg"
      end

      def thumbnail_url
        "http://img.oastatic.com/img/400/400/fit/#{self['id']}/.jpg"
      end

      def to_h
        Hash[ImageAttributeTransformation.public_instance_methods.reject { |m|
          m == :to_h
        }.map { |m|
          [m, send(m)]
        }].reject { |_, v| v.nil? }
      end
    end
  end
end
