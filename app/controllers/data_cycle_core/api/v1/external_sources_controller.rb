module DataCycleCore
  class Api::V1::ExternalSourcesController < Api::V1::ApiBaseController
    def update
      api_strategy = api_strategy
      content = content_params.as_json

      updated = api_strategy.update content

      updated.each do |item|
        item.available_locales.each do |locale|
          I18n.with_locale(locale) do
            item.update(webhook_source: permitted_params[:webhook_source]) if permitted_params[:webhook_source].present?
          end
        end
      end

      updated.first.available_locales.each do |locale|
        I18n.with_locale(locale) do
          execute_after_update_webhooks updated.first if updated.is_a?(Array)
        end
      end

      # FIXME: Jbuilder Bug: tries to render jbuilder partial
      render plain: { 'updated' => updated }.to_json, content_type: 'application/json'
    end

    def create
      api_strategy = api_strategy
      content = content_params.as_json

      created = api_strategy.create content

      execute_after_create_webhooks created.first if created.is_a?(Array)

      # FIXME: Jbuilder Bug: tries to render jbuilder partial
      render plain: { 'created' => created }.to_json, content_type: 'application/json'
    end

    def destroy
      api_strategy = api_strategy
      content = content_params.as_json

      deleted = api_strategy.delete content

      execute_after_delete_webhooks deleted

      # FIXME: Jbuilder Bug: tries to render jbuilder partial
      render plain: { 'deleted' => deleted }.to_json, content_type: 'application/json'
    end

    private

    def content_params
      params.require(:content)
    end

    def permitted_parameter_keys
      super + [:external_source_id, :type, :external_key, :webhook_source]
    end

    def api_strategy
      external_source = DataCycleCore::ExternalSource.find(permitted_params[:external_source_id])
      api_strategy = DataCycleCore.allowed_api_strategies.find { |object| object == external_source.config['api_strategy'] }

      api_strategy&.constantize&.new(external_source, permitted_params[:type], permitted_params[:external_key])
    end

    def execute_after_update_webhooks(data)
      Webhook::Update.execute_all(data)
    end

    def execute_after_delete_webhooks(data)
      Webhook::Delete.execute_all(data)
    end

    def execute_after_create_webhooks(data)
      Webhook::Create.execute_all(data)
    end
  end
end
