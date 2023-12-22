# frozen_string_literal: true

module DataCycleCore
  module Api
    module Config
      class SchemaController < ::DataCycleCore::Api::Config::ApiBaseController
        before_action :prepare_url_parameters

        def index
          contents = DataCycleCore::ThingTemplate.all.to_a
          render json: schema_api_format(contents) { contents.map(&:schema_sorted) }.to_json
          # else
          #   render json: { error: 'No ids given!' }, layout: false, status: :bad_request
          # end
        end

        def show
          name = params[:template_name]
          template = DataCycleCore::ThingTemplate.where(template_name: name)
          if template.present?
            render json: template.first.schema_sorted.to_json
          else
            error = "Couldn't find ThingTemplate #{name}"
            raise ActiveRecord::RecordNotFound.new(error)
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
      end
    end
  end
end
