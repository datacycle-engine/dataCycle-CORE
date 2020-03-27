# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class UniversalController < ::DataCycleCore::Api::V4::ApiBaseController
        before_action :prepare_url_parameters

        def show
          if permitted_params[:id].blank?
            render json: { error: 'No id given!' }, layout: false, status: :bad_request
          elsif DataCycleCore::Thing.find_by(id: permitted_params[:id]).present?
            redirect_to api_v4_thing_path(id: permitted_params[:id], params: permitted_params.except(:id))
          elsif DataCycleCore::ClassificationTreeLabel.find_by(id: permitted_params[:id]).present?
            redirect_to api_v4_concept_scheme_path(id: permitted_params[:id], params: permitted_params.except(:id))
          elsif (concept = DataCycleCore::ClassificationAlias.find_by(id: permitted_params[:id])).present?
            redirect_to classifications_api_v4_concept_scheme_path(id: concept.classification_tree_label.id, classification_id: permitted_params[:id], params: permitted_params.except(:id))
          elsif (concept = DataCycleCore::Classification.find_by(id: permitted_params[:id])&.primary_classification_alias).present?
            redirect_to classifications_api_v4_concept_scheme_path(id: concept.classification_tree_label.id, classification_id: concept.id, params: permitted_params.except(:id))
          elsif (@content = DataCycleCore::Schedule.find_by(id: permitted_params[:id])).present?
            render template: 'data_cycle_core/api/v4/schedules/show', locals: { id: permitted_params[:id] }, layout: false
          else
            render json: { error: "Could not find any item with id=#{permitted_params[:id]}" }, layout: false, status: :bad_request
          end
        end

        private

        def permitted_parameter_keys
          super + [:id, :language, :include, :fields, :format]
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
          @include_parameters = parse_tree_params(permitted_params.dig(:include))
          @fields_parameters = parse_tree_params(permitted_params.dig(:fields))
          @field_filter = @fields_parameters.present?
          @language = parse_language(permitted_params.dig(:language)).presence || Array(I18n.available_locales.first.to_s)
          @api_subversion = permitted_params.dig(:api_subversion) if DataCycleCore.main_config.dig(:api, :v4, :subversions)&.include?(permitted_params.dig(:api_subversion))
          @api_version = 4
        end
      end
    end
  end
end
