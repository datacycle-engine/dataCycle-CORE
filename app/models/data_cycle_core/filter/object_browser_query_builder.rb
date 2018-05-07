module DataCycleCore
  module Filter
    class ObjectBrowserQueryBuilder < Search
      def initialize(locale = 'de', definition = nil, query = nil)
        @locale = locale
        @query = query || super(locale, query)

        if definition.present? && definition.fetch(:linked_table, nil).present? && definition.fetch(:template_name, nil).present?
          @definition = definition
          content_data_type = ('DataCycleCore::' + (@definition[:linked_table]).to_s.classify).constantize
          data_type = @definition[:template_name]
          @query = @query.where('content_data_type = ? AND data_type = ? ', content_data_type, data_type)
        end
      end

      private

      def reflect(query)
        self.class.new(@locale, @definition, query)
      end
    end
  end
end
