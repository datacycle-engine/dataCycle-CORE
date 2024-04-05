# frozen_string_literal: true

module DataCycleCore
  module Api
    module Config
      class SchemaController < ::DataCycleCore::Api::Config::ApiBaseController
        before_action :authorize_user, :prepare_url_parameters

        def index
          contents = DataCycleCore::ThingTemplate.all
          render json: schema_api_format(contents) { contents.schema_as_json }.to_json
        end

        def show
          name = params[:template_name]
          template = DataCycleCore::ThingTemplate.find_by(template_name: name)
          if template.present?
            content = Array.wrap(template.schema_as_json)
            render json: schema_api_format(content) { content }.to_json
          else
            error = "Couldn't find ThingTemplate '#{name}'"
            render json: { error: }, layout: false, status: :not_found
          end
        end

        def permitted_parameter_keys
          super + [:id, :template_name]
        end

        private

        def schema_api_format(contents)
          {
            '@graph' => yield,
            'meta' => {
              total: contents.count
            }
          }
        end

        def authorize_user
          render json: { error: 'Forbidden' }, layout: false, status: :forbidden unless current_user&.is_role?('super_admin')
        end
      end
    end
  end
end
