# frozen_string_literal: true

module DataCycleCore
  module Api
    module Config
      # Serves the per-instance RDF schema generated from the DataDefinitions (#50196),
      # split into three endpoints with distinct jobs:
      #   * GET /api/config/rdf/ontology — RDFS/OWL ontology (the data model, TBox)
      #   * GET /api/config/rdf/shapes   — SHACL shapes (the validation rules)
      #   * GET /api/config/rdf/context  — the JSON-LD @context (separately cacheable)
      # Ontology and shapes are content-negotiated to Turtle / JSON-LD / RDF-XML /
      # N-Triples via a format extension (.ttl/.jsonld/.rdf/.nt) or the Accept header.
      #
      # The three routes exist only when the instance has the API enabled: config/routes.rb
      # wraps the whole `namespace :api` in `if DataCycleCore.main_config.dig(:api, :enabled)`,
      # so with it off they are never drawn and a request 404s from the router. No
      # per-controller guard is involved.
      class RdfController < ::DataCycleCore::Api::Config::ApiBaseController
        before_action :prepare_url_parameters
        before_action :disable_response_caching

        # RDFS/OWL ontology of the instance (cached; multilingual, so locale-independent).
        def ontology
          authorize!(:index, :api_config_rdf)
          render_document(:ontology)
        end

        # SHACL shapes validating the instance's JSON-LD against the DataDefinitions.
        def shapes
          authorize!(:index, :api_config_rdf)
          render_document(:shapes)
        end

        # Standalone JSON-LD @context document (prefix/term mapping).
        def context
          authorize!(:index, :api_config_rdf)
          render json: DataCycleCore::Rdf::ContextBuilder.new.call
        end

        private

        # The RDF documents are auth-gated, so browsers/proxies must not cache them:
        # a cached copy would otherwise still be shown after logout or with a wrong
        # token. no-store also suppresses the automatic ETag/must-revalidate response.
        def disable_response_caching
          response.headers['Cache-Control'] = 'no-store'
        end

        # Renders the cached, serialized document for a kind in the negotiated RDF
        # format with the matching content type.
        def render_document(kind)
          format = negotiated_format
          render plain: DataCycleCore::Rdf::Cache.document(kind, format),
                 content_type: DataCycleCore::Rdf::Serializer.content_type(format)
        end

        # Writer format from the URL extension (.ttl/.jsonld/.rdf/.nt), else from the
        # Accept header, else Turtle as the readable default.
        def negotiated_format
          DataCycleCore::Rdf::Serializer::FORMATS[params[:format].to_s] || accept_format || :turtle
        end

        # First writer format whose content type is listed in the Accept header.
        def accept_format
          accept = request.headers['Accept'].to_s
          DataCycleCore::Rdf::Serializer::CONTENT_TYPES.find { |_format, mime| accept.include?(mime) }&.first
        end
      end
    end
  end
end
