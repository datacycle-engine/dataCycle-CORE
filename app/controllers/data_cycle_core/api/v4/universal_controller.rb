# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class UniversalController < ::DataCycleCore::Api::V4::ApiBaseController
        def show
          render json: { error: 'No id given!' }, layout: false if permitted_params[:id].blank?
          if DataCycleCore::Thing.find_by(id: permitted_params[:id]).present?
            redirect_to api_v4_thing_path(id: permitted_params[:id])
          elsif DataCycleCore::ClassificationTreeLabel.find_by(id: permitted_params[:id]).present?
            redirect_to api_v4_concept_scheme_path(id: permitted_params[:id])
          elsif DataCycleCore::ClassificationAlias.find_by(id: permitted_params[:id]).present?
            concept = DataCycleCore::ClassificationAlias.find_by(id: permitted_params[:id])
            concept_scheme = concept.classification_tree_label
            redirect_to classifications_api_v4_concept_scheme_path(id: concept_scheme.id, classification_id: permitted_params[:id])
          else
            render json: { error: "Could not find any item with id=#{permitted_params[:id]}" }, layout: false
          end
        end

        private

        def permitted_parameter_keys
          super + [:id, :language, { language: [] }, :include, :fields, :format]
        end
      end
    end
  end
end
