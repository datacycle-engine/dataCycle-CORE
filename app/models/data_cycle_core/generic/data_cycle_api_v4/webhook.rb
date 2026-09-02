# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleApiV4
      class Webhook < DataCycleCore::Generic::Common::Webhook
        include DataCycleCore::Common::Routing

        def create(raw_data, external_system, current_user)
          @created = []
          @updated = []
          @errors = []
          @warnings = []
          @main_thing_id = nil

          return { success: false, error: 'no data' } if raw_data.blank?

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            result = upsert_content(raw_data, external_system, current_user)

            success = false

            if (@errors.blank? && result[:content].blank?) || result.blank? || !result[:content].persisted?
              success = false
            elsif @errors.blank? && result[:content].persisted?
              success = true
            elsif @errors.present? && result[:content].present? && (@updated.present? || @created.present?)
              success = 'partial'
            end

            @errors.sort_by! { |e| e[:path].join('.') }

            if result.present? && result[:content].present? && !result[:content].persisted?
              @errors.unshift({ message: 'Main thing not persisted due to some error. See errors with root path (path: []) for more details. Additionally, no other elements were persisted. Errors and warnings related to these elements are still included for reference.' })
              success = false
              raise ActiveRecord::Rollback
            end

            if result.blank? || result[:content].blank?
              { success:, error: @errors, warnings: @warnings }
            else
              # an embedded content is rendered into the cached api output of its parents, and only
              # its own row is written — so every content this push touched has to be invalidated
              # upwards, synchronously: the caller reads back over the api right after this returns.
              # The ancestors it reaches are collateral and stay out of the reported count.
              touched_ids = (@created + @updated).pluck(:thing_id).push(result[:content].id).uniq
              DataCycleCore::Thing.where(id: touched_ids).with_cached_related_contents.invalidate_all
              cache_invalidated = touched_ids.size
              {
                success:,
                meta: {
                  thing_id: result[:content].id,
                  external_key: result[:content].external_key,
                  language: result[:content].translated_locales,
                  link: result[:content].persisted? ? thing_url(result[:content]) : nil,
                  created: @created,
                  updated: @updated,
                  cache_invalidated:
                }
              }.tap do |response|
                response[:error] = @errors if @errors.present?
                response[:warnings] = @warnings if @warnings.present?
                response[:status] = @status if @status.present?
              end
            end
          rescue ActiveRecord::Rollback
            { success: false, error: @errors, warnings: @warnings, status: :bad_request }
          end
        end

        def update(raw_data, external_system, current_user)
          create(raw_data, external_system, current_user)
        end

        def delete(raw_data, external_system, current_user)
          @errors = []
          @status = nil

          if raw_data.blank?
            return {
              success: false,
              error: 'no data'
            }
          end

          result = destroy_content(raw_data, external_system, current_user)

          success = false
          if @errors.blank?
            success = true
          elsif result.blank?
            success = false
          end

          if result.blank? || result[:content].blank?
            return {
              success:,
              error: @errors
            }.tap do |response|
              response[:status] = @status if @status.present?
            end
          end

          {
            success:,
            meta: {
              thing_id: result[:content].id
            }
          }.tap do |response|
            response[:status] = @status if @status.present?
          end
        end

        def demote(raw_data, external_system, current_user)
          @errors = []
          @results = []
          @status = nil

          if raw_data.blank?
            return {
              success: false,
              error: 'no data'
            }
          end

          demote_content(raw_data, external_system, current_user)

          success = false
          success = true if @errors.blank?

          {
            success:,
            results: @results,
            errors: @errors
          }.tap do |response|
            response[:status] = @status if @status.present?
          end
        end

        private

        def t(*)
          DataCycleCore::Generic::DataCycleApiV4::TransformationFunctions[*]
        end

        def api_definition(definition)
          definition&.dig('api')&.merge(definition&.dig('api', 'v4') || {}) || {}
        end

        def upsert_content(data, external_system, current_user, path = [])
          unless data['@type'].is_a?(String)
            @errors.push({ message: 'template must be a string', path: })
            return
          end

          template_name = data['@type']&.delete_prefix('dcls:')

          if template_name.nil?
            @errors.push({ message: 'missing @type', path: })
            return
          end

          begin
            template = DataCycleCore::Thing.new(template_name:)
          rescue ActiveModel::MissingAttributeError
            @errors.push({ message: 'invalid @type: template not found', path: })
            @status = :bad_request
            return
          end

          p_mapping_orig = allowed_property_definitions(template, external_system)

          p_mapping = property_mapping(p_mapping_orig)

          base_data = base_transformation(template, p_mapping, @main_thing_id, path).call(data)
          content = DataCycleCore::Thing.first_by_external_key_or_id(base_data['external_key'], external_system.id)

          return unless allowed_to_create_or_update?(content, data, template, external_system, current_user, path, template_name)

          return { content: } if content.nil? && data.except('@type', '@id').blank?

          if path.blank?
            if template.embedded?
              @errors.push({ message: 'embedded may not be created directly', path: })
              @status = :forbidden
              return
            end
            @main_thing_id = base_data['external_key']
          end

          begin
            datahash = transformations(template, p_mapping, external_system, current_user, @main_thing_id, path).call(base_data)
          rescue ActiveRecord::RecordInvalid => e
            message = e.try(:record)&.full_errors(:de) || e.message

            if path.blank?
              @status = :bad_request
              @errors.push({ message:, path: })
              return
            else
              @warnings.push({ message:, path: })
            end
          end

          if datahash.blank?
            @errors.push({ message: 'no data after transformations', path: })
            @status = :bad_request
            return
          end

          generate_ignored_keys_warning(datahash, data, p_mapping, p_mapping_orig, path, template)

          if content.nil?
            add_default_value_definitions(template, external_system.default_options&.dig('default_values')) if external_system.default_options&.dig('default_values').present?

            content = DataCycleCore::DataHashService.create_internal_object(
              template.thing_template,
              datahash.merge({ local_import: true, external_source: external_system }),
              current_user
            )
            if content.errors.blank?
              @created.push({
                thing_id: content.id,
                external_key: content.external_key,
                template: template_name,
                key: get_key_from_path(path),
                path:
              }.compact)
            end
          elsif datahash[:datahash].keys == ['external_key']
            # do nothing --> just reference the existing content
          elsif content.external_source_id == external_system.id
            if content.template_name != template_name
              @errors.push({ message: "template mismatch: #{content.template_name} != #{template_name}", path: })
              @status = :bad_request
              return { content: }
            end
            datahash[:datahash].delete('external_key') if datahash.dig(:datahash, 'external_key').uuid? && content.id == datahash.dig(:datahash, 'external_key')
            old_updated_at = content.updated_at
            content.set_data_hash_with_translations(
              data_hash: datahash,
              current_user:
            )
            changed = content.updated_at != old_updated_at
            if changed && content.errors.blank?
              @updated.push({
                thing_id: content.id,
                external_key: content.external_key,
                template: template_name,
                key: get_key_from_path(path),
                path:
              }.compact)
            end
          elsif content.external_source_id != external_system.id
            @errors.push({ message: 'not allowed to update things from a different (external) system', path: })
            @status = :forbidden
            return { content: }
          else
            @errors.push({ message: 'not allowed', path: })
            @status = :forbidden
            return { content: }
          end

          unless content.i18n_valid?
            @errors.push({ message: content.i18n_errors.transform_values(&:messages), path: })
            @status = :bad_request
            return { content: }
          end

          { content: }
        end

        def destroy_content(data, external_system, current_user)
          external_id = data['@id']

          if external_id.blank?
            @errors.push({ message: 'missing @id' })
            @status = :bad_request
            return
          end

          content = DataCycleCore::Thing.first_by_external_key_or_id(external_id, external_system.id)

          return unless allowed_to_delete?(content, external_system, current_user, external_id)

          result = content.destroy_content(current_user:)

          unless result.destroyed?
            @errors.push({ message: 'error deleting content!' })
            return
          end

          { content: }
        rescue StandardError
          @errors.push({ message: 'error deleting content!' })
          nil
        end

        def demote_content(data, external_system, current_user)
          ids = data['ids']

          if ids.blank?
            @errors.push({ message: 'missing ids' })
            @status = :bad_request
            return
          end

          ids_not_found = []
          contents = []
          ids.each do |id|
            thing = DataCycleCore::Thing.first_by_external_key_or_id(id, external_system.id)
            (ids_not_found << id) && next if thing.blank?

            next unless allowed_to_demote?(thing, external_system, current_user, id)

            thing.external_source_to_external_system_syncs(ExternalSystemSync::SYNC_TYPES[:duplicate])
            contents << thing
          end
          @errors.push({ message: "external_key: #{ids_not_found.join(', ')} not found" }) if ids_not_found.present?

          successes = []
          contents.each do |content|
            if !content.external_source_id.nil? || !content.external_key.nil?
              @errors.push({ message: "error demoting content with id: #{content.id}, external_key: #{content.external_key}!" })
            else
              successes << content.id
            end
          end

          @results.push({ message: "Data with ids: #{successes.join(', ')} Successfully demoted" }) if successes.present?
          { contents: }
        rescue StandardError
          @errors.push({ message: 'error demoting content!' })
          nil
        end

        def add_default_value_definitions(template, default_values)
          default_values&.each do |key, definition|
            next unless template&.schema&.dig('properties')&.key?(key)

            template.schema['properties'][key]['default_value'] = definition
          end
        end

        # The keys a push may write, derived by subtraction. The additive list this replaced
        # enumerated nine property types and silently dropped every type it did not name -
        # collection, table and oembed. A required property of one of those types was then demanded
        # by the template validation and discarded here in the same request, so the content could
        # not be pushed at all.
        #
        # writable_property_names already drops virtual and inverse linked properties; computed
        # ones are subtracted here so a push cannot overwrite a value the schema derives.
        # reason_for_ignored_key names the complement of this set 'unwriteable property'.
        def pushable_property_names(template)
          template.writable_property_names - template.computed_property_names
        end

        def allowed_property_definitions(template, external_system)
          whitelist = Array.wrap(external_system.default_options&.dig('attribute_whitelist'))
          whitelist <<= 'location' if template.property?(:location)

          template.property_definitions.slice(*pushable_property_names(template)).reject do |k, v|
            whitelist.exclude?(k) && v.dig('ui', 'edit', 'disabled') == true
          end
        end

        def property_mapping(properties)
          return {} if properties.blank?

          ignore_methods = ['nest', 'combine', 'unwrap', 'append'].freeze

          mapping = properties.keys
            .index_with { |k|
              next "dc:classification:#{k}" if properties.dig(k, 'type') == 'classification'

              # reject those with ignore_methods
              next if ignore_methods.include?(api_definition(properties[k])&.dig('transformation', 'method'))

              api_definition(properties[k])&.dig('name').presence&.underscore ||
                api_definition(properties[k])&.dig('transformation', 'name').presence&.underscore ||
                k
            }
            .merge('external_key' => '@id')

          nest_keys = properties.keys.select { |k| api_definition(properties[k])&.dig('transformation', 'method') == 'nest' }
          nested_names_mapping = nest_keys.index_with do |k|
            api_definition(properties[k])&.dig('transformation', 'name').presence&.underscore || k
          end

          mapping.merge!(nested_names_mapping.values.uniq.index_by(&:itself))

          # combine_keys = properties.keys.select { |k| api_definition(properties[k])&.dig('transformation', 'method') == 'combine' }
          # unwrap_keys = properties.keys.select { |k| api_definition(properties[k])&.dig('transformation', 'method') == 'unwrap' }

          mapping.reject! { |k, _| k == 'id' }
          # same_value_properties = mapping.select { |k, v| mapping.values.count(v) > 1 && k != v && k.present? && v.present? }
          # grouped_properties = same_value_properties.group_by { |k, v| v }
          mapping.reject! { |k, v| v == 'potential_action' && k != 'potential_action' }
          mapping
        end

        def allowed_to_create_or_update?(content, data, template, external_system, current_user, path, template_name)
          if (Array.wrap(external_system.default_options&.dig('allowed_linked_templates')) + Array.wrap(external_system.default_options&.dig('allowed_templates')))&.exclude?(template_name)
            @errors.push({ message: 'forbidden @type', path: })
            @status = :forbidden
            return false
          end

          if content.nil?
            if data.except('@type', '@id').blank?
              message = "thing with id #{data['@id']} not found"
              if path.blank?
                @status = :not_found
                @errors.push({ message:, path: })
              else
                @warnings.push({ message:, path: })
              end
              return false
            end

            if Array.wrap(external_system.default_options&.dig('allowed_templates')).exclude?(template_name)
              @errors.push({ message: 'readonly @type: not allowed to create', path: })
              @status = :forbidden
              return false
            end

            unless template.embedded? || current_user.can?(:create, template, 'all') || current_user.can?(:create, template, 'push_api')
              @errors.push({ message: "not allowed to create content with template '#{template_name}'", path: })
              @status = :forbidden
              return false
            end
          else
            if data.except('@type', '@id').blank?
              # we are just referencing an existing thing
              return true
            end

            unless template.embedded? || current_user.can?(:update, content) || current_user.can?(:update, content, 'push_api')
              @errors.push({ message: 'not allowed to update content', path: })
              @status = :forbidden
              return false
            end
          end
          true
        end

        def allowed_to_delete?(content, external_system, current_user, external_id)
          if content.nil?
            @errors.push({ message: "content with @id '#{external_id}' not found" })
            @status = :not_found
            return false
          end

          if content.embedded?
            @errors.push({ message: 'embedded content cannot be deleted directly' })
            @status = :forbidden
            return false
          end

          unless current_user.id == content.created_by || current_user.can?(:destroy, content)
            @errors.push({ message: 'not allowed to delete content' })
            @status = :forbidden
            return false
          end

          if external_system.id != content.external_source_id
            @errors.push({ message: 'cannot delete things from a different (external) system' })
            @status = :forbidden
            return false
          end

          if external_system.default_options&.dig('allowed_templates')&.exclude?(content.thing_template.template_name)
            @errors.push({ message: 'not allowed to delete this content with this template' })
            @status = :forbidden
            return false
          end
          true
        end

        def allowed_to_demote?(content, external_system, current_user, external_id)
          if content.nil?
            @errors.push({ message: "content with @id '#{external_id}' not found" })
            @status = :not_found
            return false
          end

          unless current_user.id == content.created_by || current_user.can?(:demote_primary_external_system, content)
            @errors.push({ message: "not allowed to demote content with id: #{content.id}" })
            @status = :forbidden
            return false
          end

          if external_system.id != content.external_source_id
            @errors.push({ message: 'cannot delete things from a different (external) system' })
            @status = :forbidden
            return false
          end
          true
        end

        def generate_ignored_keys_warning(datahash, data, p_mapping, p_mapping_orig, path, template)
          data_keys_transformed = data.keys.map { |k| p_mapping[k.underscore] || k.underscore }
          datahash_keys_transformed = datahash[:datahash].keys.map { |k| p_mapping[k.underscore] || k.underscore }
          ignored_keys = (data_keys_transformed - datahash_keys_transformed) - ['@type', '@id'] - ['format', 'controller', 'action', 'external_source_id']
          ignored_keys_with_reason = ignored_keys.map { |k| [k, reason_for_ignored_key(k, template, p_mapping_orig)] }
          # ignored_keys_original = Array.new(ignored_keys.size) { |i| data.keys.find { |k| p_mapping[k.underscore] == ignored_keys[i] || k.underscore == ignored_keys[i] } || ignored_keys[i] }
          ignored_keys_original_with_reason = ignored_keys_with_reason.map { |k, r| [data.keys.find { |key| p_mapping[key.underscore] == k || key.underscore == k } || k, r] }
          # @warnings.push({ message: 'Some keys were ignored: ' + ignored_keys_original_with_reason.join(', '), path: }) if ignored_keys_original_with_reason.present?
          @warnings.push({ message: 'Some keys were ignored: ' + ignored_keys_original_with_reason.map { |k, r| "'#{k}' (#{r})" }.join(', '), path: }) if ignored_keys_original_with_reason.present?
        end

        def reason_for_ignored_key(ignored_key, template, _p_mapping_orig)
          if (template.property_names - pushable_property_names(template)).include?(ignored_key)
            'unwriteable property'
          elsif template.property_definitions[ignored_key].present? && template.property_definitions[ignored_key].dig('ui', 'edit', 'disabled') == true
            'disabled property'
          else
            return 'check spelling of property (spaces present)' if ignored_key.include?(' ')

            'property not defined in template'
          end
        end

        def get_key_from_path(path)
          # find the last entry that is not an integer, e.g. ['image, 0'] --> 'image'
          path.reverse.find { |element| !element.is_a?(Integer) }
        end

        def base_transformation(template, p_mapping, main_thing_id, path = [])
          t(:stringify_keys)
            .>> t(:map_keys, ->(k) { p_mapping.key(k.underscore) || k.underscore })
            .>> t(:add_external_key, template, main_thing_id, path)
            .>> t(:add_field, 'dc_path', ->(_) { path })
            .>> t(:add_field, 'dc_errors', ->(_) { [] })
            .>> t(:add_field, 'dc_warnings', ->(_) { [] })
        end

        def transformations(template, p_mapping, external_system, current_user, _main_thing_id, path = [])
          t(:reject_keys_by_permissions, template, current_user)
            .>> t(:map_linked_values, template, ->(v, key, index) { upsert_content(v, external_system, current_user, path + [p_mapping[key].camelize(:lower)] + [index])&.dig(:content)&.id }, external_system)
            .>> t(:map_embedded_values, template, external_system, ->(v, key, index) { upsert_content(v, external_system, current_user, path + [p_mapping[key].camelize(:lower)] + [index])&.dig(:content)&.id })
            .>> t(:map_schedule_values, template, external_system)
            .>> t(:map_timeseries_values, template)
            .>> t(:map_included_values, template, p_mapping, ->(s, pm) { included_transformation(pm).call(s) }, method(:property_mapping))
            .>> t(:add_geo_location, template)
            .>> t(:map_asset_values, template, lambda { |k, s|
                  t(:local_asset, k, template.properties_for(k)&.dig('asset_type'), current_user&.id, true).call(s)
                })
            .>> t(:map_classification_values, template)
            .>> t(:map_collection_values, template)
            .>> t(:extract_errors_and_warnings, @errors, @warnings)
            .>> t(:accept_keys, p_mapping.keys)
            .>> t(:json_ld_to_translated_data_hash)
        end

        def included_transformation(p_mapping)
          t(:stringify_keys)
            .>> t(:map_keys, ->(k) { p_mapping.key(k.underscore) || k.underscore })
            .>> t(:accept_keys, p_mapping.keys)
        end
      end
    end
  end
end
