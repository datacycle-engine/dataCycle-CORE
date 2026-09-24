# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for the content-scoped duplicate-candidate endpoints
      # (config/routes.rb -> Api::V4::DuplicatesController): list the candidates of a
      # content, mark a pair manually, merge a pair and dismiss a pair as a false
      # positive. Documented in docs/api/contents/duplicates.md.
      #
      # All four require the `merge_duplicates` ability for BOTH contents and the
      # `duplicate_candidate` feature; without the feature every route answers 404.
      module Duplicates
        module_function

        TAGS = ['Duplicates'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/things/{id}/duplicates' => { 'get' => index, 'post' => create },
            '/things/{id}/duplicates/{duplicate_id}/merge' => { 'post' => merge },
            '/things/{id}/duplicates/{duplicate_id}/false_positive' => { 'post' => false_positive }
          }
        end

        # ---- shared path parameters -----------------------------------------

        # Path parameter for the content whose duplicates are addressed.
        def id_param
          Common.id_path_param('id', t('paths.duplicates.id'))
        end

        # Path parameter for the duplicate content of the pair.
        def duplicate_id_param
          Common.id_path_param('duplicate_id', t('paths.duplicates.duplicate_id'))
        end

        # ---- operations ------------------------------------------------------

        # GET /things/{id}/duplicates -- the candidates of one content. Sorting is
        # fixed (dc:score desc, then @id), so `sort` is intentionally not offered:
        # the paging over equally scored pairs depends on that order.
        def index
          Common.operation(
            operation_id: 'getThingDuplicates',
            summary: t('paths.duplicates.index_summary'),
            tags: TAGS,
            parameters: [id_param, false_positive_parameter, *paging_parameters, Common.parameter_ref('sectionMeta'), Common.parameter_ref('language'), Common.parameter_ref('token')],
            responses: { '200' => duplicates_response(t('paths.duplicates.index_response')) }.merge(error_responses)
          )
        end

        # POST /things/{id}/duplicates -- mark a pair manually (method `manual`,
        # score 100). 201 when newly marked, 200 when it already was.
        def create
          Common.write_operation(
            operation_id: 'markThingDuplicate',
            summary: t('paths.duplicates.create_summary'),
            description: t('paths.duplicates.create_description'),
            tags: TAGS,
            parameters: [id_param],
            request_body: Common.json_request_body(mark_request),
            responses: {
              '200' => duplicates_response(t('paths.duplicates.create_existing_response')),
              '201' => Common.created_response(t('paths.duplicates.create_response'), schema: body_schema)
            }.merge(error_responses)
          )
        end

        # POST .../merge -- queue MergeDuplicateJob; the pair disappears at once, the
        # merge itself runs asynchronously, hence 202 rather than 200.
        def merge
          Common.write_operation(
            operation_id: 'mergeThingDuplicate',
            summary: t('paths.duplicates.merge_summary'),
            description: t('paths.duplicates.merge_description'),
            tags: TAGS,
            parameters: [id_param, duplicate_id_param],
            responses: { '202' => Common.accepted_response(t('paths.duplicates.merge_response'), schema: body_schema) }.merge(Common.write_error_responses)
          )
        end

        # POST .../false_positive -- dismiss the pair. It stays readable via
        # `falsePositive=true` and can be reactivated by marking it again.
        def false_positive
          Common.write_operation(
            operation_id: 'dismissThingDuplicate',
            summary: t('paths.duplicates.false_positive_summary'),
            description: t('paths.duplicates.false_positive_description'),
            tags: TAGS,
            parameters: [id_param, duplicate_id_param],
            responses: { '200' => duplicates_response(t('paths.duplicates.false_positive_response')) }.merge(Common.write_error_responses)
          )
        end

        # ---- parameters / bodies --------------------------------------------

        # `falsePositive=true` lists the dismissed pairs instead of the active ones.
        def false_positive_parameter
          {
            'name' => 'falsePositive',
            'in' => 'query',
            'required' => false,
            'description' => t('paths.duplicates.false_positive_param'),
            'schema' => { 'type' => 'boolean', 'default' => false }
          }
        end

        # Only the paging parameters DuplicatesController#page_settings evaluates --
        # the remaining list parameters (sort/filter/fields/include) are accepted but
        # have no effect here, so offering them would be a false promise.
        def paging_parameters
          ['pageSize', 'pageNumber', 'pageOffset', 'pageLimit'].map { |name| Common.parameter_ref(name) }
        end

        # Request body of POST /duplicates: the @id of the content to mark as a
        # duplicate of {id}.
        def mark_request
          {
            'type' => 'object',
            'title' => 'DuplicateMarkRequest',
            'description' => t('paths.duplicates.mark_request'),
            'required' => ['@id'],
            'properties' => { '@id' => { 'type' => 'string', 'format' => 'uuid', 'description' => t('paths.duplicates.mark_request_id') } }
          }
        end

        # 400/401/404/422 for every operation here -- the READ operation included:
        # DuplicatesController#set_content is a before_action for all of them and
        # answers 422 for an embedded content, which can never have duplicates.
        def error_responses
          Common.write_error_responses
        end

        # The 200/201/202 response of every operation here: the current candidates.
        def duplicates_response(description)
          Common.json_response(description, body_schema)
        end

        # Inlined rather than registered as a component, the way the other
        # non-envelope bodies are handled (Schemas::ResponseBodies).
        def body_schema
          DataCycleCore::OpenApi::Schemas::ResponseBodies.duplicate_collection
        end
      end
    end
  end
end
