# frozen_string_literal: true

module DataCycleCore
  module StoredFilterExtensions
    module FilterParamsHashParser
      extend ActiveSupport::Concern

      delegate :param_from_definition, to: DataCycleCore::StoredFilterParametersType

      def parameters_from_hash(params_array)
        return self if params_array.blank?

        self.parameters = params_array.map { |filter| param_from_definition(filter) }

        self
      end

      def apply_user_filter(user, options = nil, filter_reset = false)
        return self if user.nil?

        filter_options = { scope: 'backend' }
        filter_options.merge!(options) { |_k, v1, v2| v2.presence || v1 } if options.present?
        filter_options[:scope] = Array.wrap(filter_options[:scope])
        filter_options[:scope] = filter_options[:scope].flat_map { |v| [v, "#{v}_reset"] } if filter_reset

        self.parameters ||= []
        applicable_filters = user_filters_from_hash(user, filter_options)
        parameters.each { |f| f['c'] = 'a' if f['c'].in?(['u', 'uf']) && applicable_filters.none? { |af| filter_equal?(af, f, false) } }

        self.parameters = user.default_filter(parameters, filter_options) # keep for backwards compatibility

        applicable_filters.each { |f| apply_specific_user_filter(f) }

        self
      end

      private

      def apply_specific_user_filter(filter)
        parameters.reject! { |f| filter_equal?(f, filter, false) } if filter['c'] == 'uf'
        parameters.push(filter) unless parameters.any? { |f| filter_equal?(f, filter, false) }
      end

      def user_filters_from_hash(user, filter_options)
        user_filters = []

        DataCycleCore.user_filters&.each_value do |f|
          next if f.blank?
          next unless Array.wrap(f['scope']).intersect?(filter_options[:scope])
          next if Array.wrap(f['segments']).none? { |s| s['name'].safe_constantize.new(*Array.wrap(s['parameters'])).include?(user) }

          next if filter_options[:scope].include?('object_browser') && !relevant_for_object_browser?(f, filter_options)

          user_filters.concat(Array.wrap(f['stored_filter']).map { |s| param_from_definition(s, f['force'] ? 'uf' : 'u', user) })
        end

        user_filters
      end

      def relevant_for_object_browser?(filter, options)
        return true if filter['object_browser_restriction'].blank?

        content = options[:content]
        return false if content.nil?

        template_names = content.relevant_template_names
        attribute_names = content.relevant_property_names(options[:attribute_key])

        filter['object_browser_restriction'].to_h.any? do |k, v|
          template_names.include?(k) && attribute_names.intersect?(Array.wrap(v))
        end
      end
    end
  end
end
