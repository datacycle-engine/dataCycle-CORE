# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class UniversalController < ::DataCycleCore::Api::V4::ApiBaseController
        before_action :prepare_url_parameters

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

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
          elsif (id = DataCycleCore::Thing.find_by('id::VARCHAR ILIKE ?', "#{permitted_params[:id][0..-14]}%")&.id).present? # for generated uuids in e.g. DZT exported Things
            redirect_to api_v4_thing_path(id: id, params: permitted_params.except(:id))
          else
            render json: { error: "Could not find any item with id=#{permitted_params[:id]}" }, layout: false, status: :bad_request
          end
        end

        private

        def permitted_parameter_keys
          super + [:id, :language]
        end
      end
    end
  end
end
