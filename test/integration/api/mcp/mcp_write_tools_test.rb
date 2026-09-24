# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module Mcp
      # Functional tests for the writing tools (create_content/update_content) on both mounts:
      # the config gate that keeps them out of a read-only installation, the write itself, and the
      # two properties a read-only tool never needed -- that a failed write creates NOTHING and that
      # silently dropped attributes are reported back instead of read as "saved".
      class McpWriteToolsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        include DataCycleCore::McpTestHelper

        before(:all) do
          DataCycleCore::Thing.delete_all

          @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
          @user.update!(access_token: SecureRandom.hex) if @user.access_token.blank?

          @guest = DataCycleCore::User.find_or_create_by!(email: 'mcp_write_guest@datacycle.at') do |user|
            user.given_name = 'MCP Write'
            user.family_name = 'Guest'
            user.password = SecureRandom.hex
            user.confirmed_at = 1.day.ago
            user.role = DataCycleCore::Role.find_by(name: 'guest')
          end
          @guest.update!(access_token: SecureRandom.hex) if @guest.access_token.blank?

          @endpoint = DataCycleCore::StoredFilter.create!(
            name: 'mcp write tools test',
            user_id: @user.id,
            api: true,
            parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Artikel'] }]
          )

          @concept = DataCycleCore::ConceptScheme.find_by(name: 'Tags').concepts.first

          # A writable attribute whose API name (get_schema/list_attributes) does NOT match the
          # internal key -- determined dynamically rather than hard-coded, so the test does not hang
          # on a template change.
          @renamed_attribute = DataCycleCore::Mcp::WritableAttributes
            .new(DataCycleCore::Thing.new(template_name: 'Artikel'))
            .to_a
            .find { |a| a[:api_name].present? && a[:api_name] != a[:attribute] }
        end

        test 'list_writable_attributes names the internal keys plus the api name to bridge from get_schema' do
          with_write_enabled do
            result = call_tool('list_writable_attributes', { 'template_name' => 'Artikel' })

            assert result['creatable']
            assert_includes result['attributes'].pluck('attribute'), 'name'

            title = result['attributes'].find { |a| a['attribute'] == 'name' }

            assert title['required']
            assert title['translatable']
          end
        end

        test 'list_writable_attributes rejects an unknown template' do
          with_write_enabled do
            body = call_tool_raw('list_writable_attributes', { 'template_name' => 'NotATemplate' })

            assert body.dig('result', 'isError')
          end
        end

        # The bug that made the tool practically unusable: get_schema/list_attributes return the API
        # names of the reading API, while writing goes through the internal keys. Without the
        # back-translation such a call looked like a success (only the title landed).
        test 'create_content translates a rejected api name back into the writable key' do
          skip 'template has no attribute with a differing api name' if @renamed_attribute.blank?

          with_write_enabled do
            result = call_tool('create_content', {
              'template_name' => 'Artikel',
              'data' => { 'name' => 'MCP Write Api Name', @renamed_attribute[:api_name] => 'x' }
            })

            assert_includes result['ignored_attributes'], @renamed_attribute[:api_name]
            assert_equal @renamed_attribute[:attribute], result.dig('attribute_name_corrections', @renamed_attribute[:api_name])
          end
        end

        # One id kind since Redmine #41458: what resolve_concepts returns is what a classification
        # attribute stores, so the write side has nothing to translate.
        test 'create_content writes the concept ids a client gets from resolve_concepts' do
          skip 'no tag concept' if @concept.blank?

          with_write_enabled do
            result = call_tool('create_content', { 'template_name' => 'Artikel', 'data' => { 'name' => 'MCP Write Concept', 'tags' => [@concept.id] } })

            assert_includes result['applied_attributes'], 'tags'
            assert_equal [@concept.id], DataCycleCore::Thing.find(result['id']).tags.map(&:id)
          end
        end

        test 'create_content with only api names fails and names both the correction and the discovery tool' do
          skip 'template has no attribute with a differing api name' if @renamed_attribute.blank?

          with_write_enabled do
            body = call_tool_raw('create_content', { 'template_name' => 'Artikel', 'data' => { @renamed_attribute[:api_name] => 'x' } })
            detail = body.dig('result', 'structuredContent', 'errors', 0, 'detail').to_s

            assert body.dig('result', 'isError')
            assert_includes detail, @renamed_attribute[:attribute]
            assert_includes detail, 'list_writable_attributes'
          end
        end

        test 'tools/list hides the write tools while write_enabled is off' do
          jsonrpc_post('tools/list', {}, token: @user.access_token)

          assert_response :success
          assert_not_includes tool_names, 'create_content'
          assert_not_includes tool_names, 'update_content'
          assert_not_includes tool_names, 'list_writable_attributes'
        end

        test 'tools/call create_content is unknown while write_enabled is off' do
          before_count = DataCycleCore::Thing.count
          body = call_tool_raw('create_content', { 'template_name' => 'Artikel', 'data' => { 'name' => 'must not exist' } })

          assert body.key?('error') || body.dig('result', 'isError')
          assert_equal before_count, DataCycleCore::Thing.count
        end

        test 'tools/list exposes the write tools on both mounts when write_enabled is on' do
          with_write_enabled do
            jsonrpc_post('tools/list', {}, token: @user.access_token)

            assert_response :success
            assert_includes tool_names, 'create_content'
            assert_includes tool_names, 'update_content'

            jsonrpc_post('tools/list', {}, token: @user.access_token, endpoint_id: @endpoint.id)

            assert_response :success
            assert_includes tool_names, 'create_content'
            assert_includes tool_names, 'update_content'
          end
        end

        test 'create_content persists the content and names the attributes it actually wrote' do
          with_write_enabled do
            result = call_tool('create_content', { 'template_name' => 'Artikel', 'data' => { 'name' => 'MCP Write Alpha' } })

            content = DataCycleCore::Thing.find(result['id'])

            assert_equal 'Artikel', content.template_name
            assert_equal 'MCP Write Alpha', content.title
            assert result['created']
            assert_includes result['applied_attributes'], 'name'
            assert_empty result['ignored_attributes']
            assert_equal @user.id, content.created_by
          end
        end

        test 'create_content also works on the endpoint mount' do
          with_write_enabled do
            result = call_tool('create_content', { 'template_name' => 'Artikel', 'data' => { 'name' => 'MCP Write Endpoint' } }, endpoint_id: @endpoint.id)

            assert_equal 'MCP Write Endpoint', DataCycleCore::Thing.find(result['id']).title
          end
        end

        # set_data_hash slices keys the template does not know without a word (see
        # Content::DataHash#set_data_hash). Reported as a plain success, an LLM would tell the user
        # the attribute was saved.
        test 'create_content reports attributes the template does not know instead of dropping them silently' do
          with_write_enabled do
            result = call_tool('create_content', { 'template_name' => 'Artikel', 'data' => { 'name' => 'MCP Write Ignored', 'not_a_real_attribute' => 'x' } })

            assert_includes result['applied_attributes'], 'name'
            assert_equal ['not_a_real_attribute'], result['ignored_attributes']
          end
        end

        # A failed validation rolls the creation back, but the returned object keeps its id --
        # reporting that id as success would name a record that does not exist.
        test 'create_content answers with an error and creates nothing when a validation fails' do
          with_write_enabled do
            before_count = DataCycleCore::Thing.count
            body = call_tool_raw('create_content', { 'template_name' => 'Artikel', 'data' => { 'internal_name' => 'no title given' } })

            assert body.dig('result', 'isError')
            assert_predicate body.dig('result', 'structuredContent', 'errors', 0, 'detail'), :present?
            assert_equal before_count, DataCycleCore::Thing.count
          end
        end

        # The same failed validation as above, only in a DIFFERENT language than the request
        # language. Content#errors is language-bound (@errors[I18n.locale]) and is filled under the
        # write language -- read outside I18n.with_locale the field list was empty and the client got
        # an error without any explanation.
        test 'create_content names the failing fields when writing another language' do
          with_write_enabled do
            before_count = DataCycleCore::Thing.count
            body = call_tool_raw('create_content', { 'template_name' => 'Artikel', 'data' => { 'internal_name' => 'no title given' } }, language: 'en')

            assert body.dig('result', 'isError')
            assert_predicate body.dig('result', 'structuredContent', 'errors', 0, 'detail'), :present?
            assert_equal before_count, DataCycleCore::Thing.count
          end
        end

        # The counter-check on the same mechanism, this time without an error: warnings are equally
        # language-bound. An update that changes nothing is acknowledged by set_data_hash with the
        # warning "no changes" (Content::DataHash#no_changes) -- read in the wrong language it never
        # arrived, and the response was indistinguishable from a real write.
        test 'update_content reports a write that changed nothing instead of confirming it' do
          with_write_enabled do
            created = call_tool('create_content', { 'template_name' => 'Artikel', 'data' => { 'name' => 'MCP Write Unchanged' } }, language: 'en')
            result = call_tool('update_content', { 'id' => created['id'], 'data' => { 'name' => 'MCP Write Unchanged' } }, language: 'en')

            # warnings first: that is the assertion which breaks without the language-correct
            # evaluation.
            assert_predicate result['warnings'], :present?
            assert_includes result['applied_attributes'], 'name'
            assert_empty result['changed_attributes']
          end
        end

        test 'update_content names the attributes it really changed' do
          with_write_enabled do
            content = create_content('Artikel', { name: 'MCP Write Changed Before' }, @user)
            result = call_tool('update_content', { 'id' => content.id, 'data' => { 'name' => 'MCP Write Changed After' } })

            assert_includes result['changed_attributes'], 'name'
          end
        end

        # An empty data is schema-conformant (data is deliberately open) and ran into a message that
        # did not name the error ("ignored: ").
        test 'create_content rejects an empty data hash and names the discovery tool' do
          with_write_enabled do
            body = call_tool_raw('create_content', { 'template_name' => 'Artikel', 'data' => {} })
            detail = body.dig('result', 'structuredContent', 'errors', 0, 'detail').to_s

            assert body.dig('result', 'isError')
            assert_includes detail, 'no attributes given'
            assert_includes detail, 'list_writable_attributes'
          end
        end

        test 'create_content rejects an unknown template' do
          with_write_enabled do
            body = call_tool_raw('create_content', { 'template_name' => 'NotATemplate', 'data' => { 'name' => 'x' } })

            assert body.dig('result', 'isError')
            assert_includes body.dig('result', 'structuredContent', 'errors', 0, 'detail').to_s, 'NotATemplate'
          end
        end

        test 'create_content rejects a token whose role must not create the template' do
          with_write_enabled do
            before_count = DataCycleCore::Thing.count
            body = call_tool_raw('create_content', { 'template_name' => 'Artikel', 'data' => { 'name' => 'MCP Write Denied' } }, token: @guest.access_token)

            assert body.dig('result', 'isError')
            assert_equal before_count, DataCycleCore::Thing.count
          end
        end

        # The counterpart to the create case above. Without this test only the "create new" route was
        # secured against the ability -- changing an EXISTING content, i.e. the case with the greater
        # damage, was unchecked.
        test 'update_content rejects a token whose role must not update the content' do
          with_write_enabled do
            content = create_content('Artikel', { name: 'MCP Update Denied Before' }, @user)
            body = call_tool_raw('update_content', { 'id' => content.id, 'data' => { 'name' => 'MCP Update Denied After' } }, token: @guest.access_token)

            assert body.dig('result', 'isError')
            assert_equal 'MCP Update Denied Before', content.reload.title
          end
        end

        # internal_name is stored language-neutral, name per translation: proves the flat "data"
        # hash gets split into {datahash:, translations:} instead of being written to one of them.
        test 'update_content writes only the given attributes and leaves the rest untouched' do
          with_write_enabled do
            content = create_content('Artikel', { name: 'MCP Write Before', internal_name: 'keep me' }, @user)
            result = call_tool('update_content', { 'id' => content.id, 'data' => { 'name' => 'MCP Write After' } })

            content.reload

            assert_equal 'MCP Write After', content.title
            assert_equal 'keep me', content.internal_name
            assert_not result['created']
            assert_includes result['applied_attributes'], 'name'
          end
        end

        test 'update_content adds a further translation instead of replacing the existing one' do
          with_write_enabled do
            content = create_content('Artikel', { name: 'MCP Write DE' }, @user)
            call_tool('update_content', { 'id' => content.id, 'data' => { 'name' => 'MCP Write EN' }, 'locale' => 'en' })

            content.reload

            assert_equal 'MCP Write DE', I18n.with_locale(:de) { content.title }
            assert_equal 'MCP Write EN', I18n.with_locale(:en) { content.title }
          end
        end

        test 'update_content rejects an unknown locale instead of silently writing the default one' do
          with_write_enabled do
            content = create_content('Artikel', { name: 'MCP Write Locale' }, @user)
            body = call_tool_raw('update_content', { 'id' => content.id, 'data' => { 'name' => 'nope' }, 'locale' => 'xx' })

            assert body.dig('result', 'isError')
            assert_equal 'MCP Write Locale', content.reload.title
          end
        end

        # Without a locale argument the write language is the requested language -- on BOTH mounts.
        # Were the :locale key missing from the endpoint server's context, the same call would
        # silently write into the instance's default language there: the client would get a
        # confirmation carrying the requested title while the title sits in another translation.
        test 'create_content writes into the requested language on both mounts' do
          with_write_enabled do
            [nil, @endpoint.id].each do |endpoint_id|
              result = call_tool('create_content', { 'template_name' => 'Artikel', 'data' => { 'name' => 'MCP Write Language' } }, endpoint_id:, language: 'en')

              assert_equal 'en', result['locale'], "mount #{endpoint_id || 'global'} wrote another language"

              content = DataCycleCore::Thing.find(result['id'])

              assert_equal 'MCP Write Language', I18n.with_locale(:en) { content.title }
              assert_empty content.translations.where(locale: 'de')
            end
          end
        end

        # An id set by the model would turn a create into an overwrite of some existing record --
        # which is why id (like external_key) is not in the whitelist although an importer is allowed
        # to set it (see Mcp::WritableAttributes).
        test 'create_content ignores an id in the data instead of overwriting that content' do
          with_write_enabled do
            existing = create_content('Artikel', { name: 'MCP Write Untouched' }, @user)
            result = call_tool('create_content', { 'template_name' => 'Artikel', 'data' => { 'name' => 'MCP Write Hijack', 'id' => existing.id } })

            assert_not_equal existing.id, result['id']
            assert_includes result['ignored_attributes'], 'id'
            assert_equal 'MCP Write Untouched', existing.reload.title
          end
        end

        test 'create_content ignores an external_key that would hand the content to an importer' do
          with_write_enabled do
            result = call_tool('create_content', { 'template_name' => 'Artikel', 'data' => { 'name' => 'MCP Write Key', 'external_key' => 'hijacked' } })

            assert_includes result['ignored_attributes'], 'external_key'
            assert_nil DataCycleCore::Thing.find(result['id']).external_key
          end
        end

        test 'create_content refuses an embedded template, which can only exist inside a parent' do
          skip 'no embedded template available' if embedded_template.blank?

          with_write_enabled do
            body = call_tool_raw('create_content', { 'template_name' => embedded_template.template_name, 'data' => { 'name' => 'x' } })

            assert body.dig('result', 'isError')
          end
        end

        # An embedded content has no data life of its own: it is written through its parent's
        # datahash attribute. Addressed directly, set_data_hash_with_translations would run against
        # an object whose parent knows nothing of the change.
        test 'update_content refuses an embedded content and names its parent as the way in' do
          skip 'no embedded template available' if embedded_template.blank?

          embedded = DataCycleCore::Thing.new(thing_template: embedded_template)
          embedded.created_by = @user.id
          embedded.save(validate: false)

          with_write_enabled do
            body = call_tool_raw('update_content', { 'id' => embedded.id, 'data' => { 'name' => 'x' } })
            detail = body.dig('result', 'structuredContent', 'errors', 0, 'detail').to_s

            assert body.dig('result', 'isError')
            assert_includes detail, 'embedded'
            assert_includes detail, 'parent'
          end
        end

        private

        def embedded_template
          @embedded_template ||= DataCycleCore::ThingTemplate.all.find { |t| t.schema['content_type'] == 'embedded' }
        end

        # Both mounts read write_enabled from their own main_config section (api.mcp /
        # api.v4.mcp), so both have to be switched for the endpoint-mount assertions.
        def tool_names
          response.parsed_body.dig('result', 'tools').to_a.pluck('name')
        end

        def call_tool(name, arguments, token: nil, endpoint_id: nil, language: nil)
          body = call_tool_raw(name, arguments, token:, endpoint_id:, language:)

          assert_not body.dig('result', 'isError'), "tool #{name} failed: #{body.dig('result', 'structuredContent').inspect}"

          body.dig('result', 'structuredContent', 'data')
        end

        def call_tool_raw(name, arguments, token: nil, endpoint_id: nil, language: nil)
          jsonrpc_post('tools/call', { 'name' => name, 'arguments' => arguments }, token: token || @user.access_token, endpoint_id:, language:)

          assert_response :success
          response.parsed_body
        end
      end
    end
  end
end
