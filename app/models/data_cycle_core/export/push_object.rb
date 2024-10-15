# frozen_string_literal: true

module DataCycleCore
  module Export
    class PushObject
      HTTP_METHODS = {
        create: :post,
        update: :put,
        delete: :delete
      }.freeze

      attr_reader :external_system, :locale, :logging, :filter_checked, :action
      attr_accessor :type, :path, :endpoint_method

      def initialize(action:, external_system:, locale: I18n.locale, filter_checked: false, type: nil, path: nil, endpoint_method: nil)
        @action = action.to_sym
        @locale = locale || I18n.locale
        @filter_checked = filter_checked
        @type = type
        @path = path
        @endpoint_method = endpoint_method&.to_sym

        raise "Missing external_system for #{self.class}" if external_system.blank?

        @external_system = external_system
        @logging = init_logging(:export)
      end

      def webhook_valid?(item)
        Array.wrap(external_system.export_config[:allowed_models] || 'DataCycleCore::Thing')
          .include?(item.class.name)
      end

      def filter_checked?
        !!filter_checked
      end

      def allowed?(data)
        @filter_checked = true
        webhook.filter(data, external_system)
      end

      def process(data)
        webhook.process(data:, utility_object: self)
      end

      def delete_action?
        action.to_s == 'delete'
      end

      def webhook
        external_system.export_config.dig(action, :strategy)&.safe_constantize
      end

      def http_method
        external_system.export_config.dig(action, 'method')&.to_sym ||
          external_system.export_config[:method]&.to_sym ||
          HTTP_METHODS[action]
      end

      def webhook_job_class
        external_system.export_config[:webhook]&.safe_constantize ||
          DataCycleCore::WebhookJob
      end

      def transformation
        external_system.export_config.dig(action, 'transformation')&.to_sym ||
          external_system.export_config[:transformation]&.to_sym ||
          :json_partial
      end

      def transformed_path(data)
        if endpoint.respond_to?(:path_transformation)
          endpoint.path_transformation(data, external_system, action, type, path)
        else
          transformed_path = path.presence ||
                             external_system.export_config.dig(action, 'path') ||
                             external_system.export_config[:path] ||
                             action.to_s

          format(transformed_path, id: data.try(:id), type:)
        end
      end

      def endpoint
        return @endpoint if defined? @endpoint

        @endpoint = begin
          endpoint_options = external_system.credentials(:export)
          endpoint_options[:data] = external_system.data if external_system.data.present?
          endpoint_options[:external_system_id] = external_system.id
          endpoint_options ||= {}

          external_system.export_config[:endpoint].constantize.new(**endpoint_options.symbolize_keys)
        end
      end

      def send_request(data)
        endpoint_method = @endpoint_method ||
                          external_system.export_config.dig(action, 'endpoint_method')&.to_sym ||
                          external_system.export_config[:endpoint_method]&.to_sym ||
                          :content_request

        endpoint.send(endpoint_method, utility_object: self, data:)
      end

      def reference_type
        [external_system.identifier.underscore_blanks, action.to_s, type.to_s].compact_blank.join('_')
      end

      def init_logging(type)
        return if type.blank?

        DataCycleCore::Generic::Logger::LogFile.new(type.to_s)
      end
    end
  end
end
