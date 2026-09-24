# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 path for the translate endpoint (config/routes.rb →
      # `namespace :translate` guarded by `Feature['Translate']&.enabled?`,
      # Api::Translate::TranslateController#translate_text):
      #   GET|POST /translate/text
      # This route lives under /api/translate (a sibling of /api/v4, NOT below it),
      # so the path item carries its own server override. Only merged into the
      # document when the Translate feature is enabled (#50193).
      module Translate
        module_function

        TAGS = ['Translate'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/text' => translate_text
          }
        end

        # GET|POST /translate/text — translate a text between two locales. Requires
        # the :api_translate_text ability on the Translate feature.
        def translate_text
          op = {
            'summary' => t('paths.translate.text_summary'),
            'description' => t('paths.translate.text_description'),
            'tags' => TAGS,
            'responses' => {
              '200' => Common.json_object_response(t('paths.translate.text_response'), schema: text_response_schema)
            }.merge(Common.error_responses)
          }
          {
            'servers' => [{ 'url' => '/api/translate', 'description' => t('paths.translate.server') }],
            'get' => op.merge('operationId' => 'getTranslateText', 'parameters' => query_parameters),
            'post' => op.merge('operationId' => 'postTranslateText', 'requestBody' => Common.json_request_body(request_body))
          }
        end

        # Query parameters for the GET variant (mirrored by the POST body). Built with the
        # shared Components::Parameters.query_string, like Classifications and Delivery do --
        # a local copy of that builder stood here only because of `required:`, which the
        # shared one now takes.
        def query_parameters
          [
            query_string('text', t('paths.translate.field_text'), required: true),
            query_string('source_locale', t('paths.translate.field_source_locale')),
            query_string('target_locale', t('paths.translate.field_target_locale'))
          ]
        end

        # @see DataCycleCore::OpenApi::Components::Parameters.query_string
        def query_string(...)
          DataCycleCore::OpenApi::Components::Parameters.query_string(...)
        end

        # 200 body: the translated text. The concrete key(s) are defined by the
        # configured Translate endpoint (e.g. `translated_text` / `translation`),
        # so string-valued extra properties are allowed; an empty endpoint yields
        # `{}`. Api::Translate::TranslateController#translate_text.
        def text_response_schema
          {
            'type' => 'object',
            'title' => 'TranslationResult',
            'properties' => { 'translated_text' => { 'type' => 'string' } },
            'additionalProperties' => { 'type' => 'string' }
          }
        end

        # POST request body.
        def request_body
          {
            'type' => 'object',
            'title' => 'TranslateTextRequest',
            'properties' => {
              'text' => { 'type' => 'string', 'description' => t('paths.translate.field_text') },
              'source_locale' => { 'type' => 'string', 'description' => t('paths.translate.field_source_locale') },
              'target_locale' => { 'type' => 'string', 'description' => t('paths.translate.field_target_locale') }
            },
            'required' => ['text']
          }
        end
      end
    end
  end
end
