# frozen_string_literal: true

require 'test_helper'
require 'rdf'

module DataCycleCore
  module Api
    module Config
      # Request-level coverage for the RDF schema endpoints (#50196): auth gating,
      # content negotiation (Turtle / JSON-LD / RDF-XML / N-Triples) via format
      # extension, and that the delivered documents are valid, parseable RDF / JSON-LD.
      #
      # Not covered here: the instance having the API disabled. config/routes.rb wraps
      # `namespace :api` in `if DataCycleCore.main_config.dig(:api, :enabled)`, which is
      # evaluated once while the routes are drawn, so no request-level test can reach that
      # state — stubbing main_config afterwards leaves the already-drawn routes in place.
      class RdfTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @routes = Engine.routes
          # :api_config_rdf is system_admin-only (roles/system_admin.yml), and only role
          # :system_admin loads that file — an admin/super_admin is rejected here.
          # Rejection itself is covered by AuthenticationTest's restricted-endpoint loop.
          @current_user = DataCycleCore::User.find_by(email: 'system_admin@datacycle.at')
        end

        # -------------------- auth --------------------
        test 'the RDF endpoints require authentication' do
          ['/api/config/rdf/ontology', '/api/config/rdf/shapes', '/api/config/rdf/context'].each do |path|
            get path

            assert_response :unauthorized, "#{path} was reachable without a session"
          end
        end

        # -------------------- ontology + content negotiation --------------------
        test 'GET the ontology as Turtle returns valid RDF with the instance classes' do
          sign_in(@current_user)
          get '/api/config/rdf/ontology.ttl'

          assert_response :success
          assert_equal 'text/turtle', response.media_type

          graph = ::RDF::Graph.new
          ::RDF::Reader.for(:turtle).new(response.body) { |reader| graph << reader }
          owl_class = DataCycleCore::Rdf::Namespaces.vocabulary('owl')[:Class]

          assert_operator graph.query([nil, ::RDF.type, owl_class]).count, :>, 0
        end

        test 'the ontology is content-negotiated to every RDF format' do
          sign_in(@current_user)
          {
            'ontology.jsonld' => 'application/ld+json',
            'ontology.rdf' => 'application/rdf+xml',
            'ontology.nt' => 'application/n-triples'
          }.each do |extension, media_type|
            get "/api/config/rdf/#{extension}"

            assert_response :success, "#{extension} failed"
            assert_equal media_type, response.media_type, "#{extension} wrong media type"
          end
        end

        # -------------------- shapes --------------------
        test 'GET the SHACL shapes returns node shapes' do
          sign_in(@current_user)
          get '/api/config/rdf/shapes.ttl'

          assert_response :success
          graph = ::RDF::Graph.new
          ::RDF::Reader.for(:turtle).new(response.body) { |reader| graph << reader }
          node_shape = DataCycleCore::Rdf::Namespaces.vocabulary('sh')[:NodeShape]

          assert_operator graph.query([nil, ::RDF.type, node_shape]).count, :>, 0
        end

        # -------------------- @context --------------------
        test 'GET the @context returns the namespace map as JSON-LD' do
          sign_in(@current_user)
          get '/api/config/rdf/context'

          assert_response :success
          assert_equal 'application/json', response.media_type
          assert_equal DataCycleCore::Rdf::Namespaces.all, response.parsed_body['@context']
        end
      end
    end
  end
end
