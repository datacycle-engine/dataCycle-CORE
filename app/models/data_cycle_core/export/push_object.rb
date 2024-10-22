# frozen_string_literal: true

module DataCycleCore
  module Export
    class PushObject
      HTTP_METHODS = {
        create: :post,
        update: :put,
        delete: :delete
      }.freeze

      attr_reader :external_system, :locale, :filter_checked, :action
      attr_accessor :type, :path, :endpoint_method

      def initialize(action:, **kwargs)
        @action = action.to_sym
        @locale = kwargs[:locale] || I18n.locale
        @filter_checked = kwargs[:filter_checked] || false
        @type = kwargs[:type]
        @path = kwargs[:path]
        @endpoint_method = kwargs[:endpoint_method]&.to_sym
        @transformation = kwargs[:transformation] || :json_partial

        if kwargs[:external_system].is_a?(DataCycleCore::ExternalSystem)
          @external_system = kwargs[:external_system]
        elsif kwargs[:external_system_id].is_a?(String) && kwargs[:external_system_id].uuid?
          @external_system = DataCycleCore::ExternalSystem.find(kwargs[:external_system_id])
        else
          raise ActiveModel::MissingAttributeError, "Missing external_system for #{self.class}"
        end
      end

      def webhook_valid?(item)
        return false if external_system.export_config.blank?

        allowed_models = Array.wrap(external_system.export_config[:allowed_models] || 'DataCycleCore::Thing')

        allowed_models.include?(item.class.name) && !webhook.nil?
      end

      def filter_checked?
        !!filter_checked
      end

      def allowed?(data)
        @filter_checked = true

        return false if webhook.nil?

        webhook.filter(data, external_system)
      end

      def process(data)
        return if webhook.nil?

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
          @transformation
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

        I18n.with_locale(data.try(:first_available_locale, locale) || locale) do
          endpoint.send(endpoint_method, utility_object: self, data:)
        end
      end
    end
  end
end
