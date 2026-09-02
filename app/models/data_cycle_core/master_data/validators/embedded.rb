# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for embedded objects.
      #
      # Handles validation of nested data structures (arrays or hashes)
      # that reference internal templates. Supports per-item validation,
      # translation-aware validation, and structural constraints.
      class Embedded < BasicValidator
        # Validates embedded data against the provided template.
        #
        # Accepts blank values, arrays, or hashes. Normalizes input into an array
        # and validates each embedded item against its corresponding template.
        #
        # @param data [Array<Hash>, Hash, nil] Embedded data to validate
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          if blank?(data) || data.is_a?(::Array) || data.is_a?(::Hash)
            check_data_array(Array.wrap(data), template)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.data_format_embedded',
              substitutions: {
                data:,
                template: template['label']
              }
            }
          end

          @error
        end

        private

        # Extends validations that are allowed on blank values.
        #
        # @return [Array<String>] List of validation keys allowed on blank data
        def validations_on_blank
          (super + ['min', 'max']).uniq
        end

        # Validates an array of embedded items.
        #
        # Applies configured validations, resolves templates, and validates each item.
        #
        # @param data [Array<Hash>] Embedded data items
        # @param template [Hash] Validation template
        # @return [void]
        def check_data_array(data, template)
          run_validations(data, template)

          embedded_templates = Array.wrap(template['template_name'])
            .index_with { |t| DataCycleCore::DataHashService.get_internal_template(t) }

          if template.blank? || embedded_templates.blank?
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.no_template',
              substitutions: {
                name: 'things'
              }
            }
            return
          end

          referenced_templates = referenced_template_names(data)

          data.each do |item|
            next if item.blank?

            if item.is_a?(::Hash)
              next if reference_only?(item) && reference_allowed?(item, referenced_templates, embedded_templates.keys)

              template_name = template['template_name']

              if template_name.is_a?(Array)
                specific_template_name = item.dig(:datahash, :template_name).presence || item[:template_name].presence

                raise DataCycleCore::Error::TemplateNotAllowedError.new(specific_template_name, template_name) unless template_name.include?(specific_template_name)

                template_name = specific_template_name
              end

              validate_item(item, embedded_templates[template_name])
            else
              (@error[:error][@template_key] ||= []) << {
                path: 'validation.errors.data_format_embedded',
                substitutions: {
                  data:,
                  template: template['label']
                }
              }
            end
          end
        rescue ActiveModel::MissingAttributeError
          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.no_template',
            substitutions: {
              name: 'things'
            }
          }
        end

        # Whether the item carries nothing but an id.
        #
        # Such an item references embedded content written elsewhere -- DataHash#set_embedded
        # only wires up the relation for it. There is no payload to validate, and no
        # template_name to resolve a multi-template slot with. Keys are stringified rather than
        # read by symbol so the check holds for a plain Hash too, not only the indifferent one
        # the rest of this class assumes.
        #
        # @param item [Hash] Embedded item data
        # @return [Boolean]
        def reference_only?(item)
          item.keys.map(&:to_s) == ['id']
        end

        # The id a reference-only item carries, nil for anything that is not one.
        #
        # The id has to be a single string: an array would resolve through an IN clause and pass
        # as a reference, only for set_embedded to write nothing for it.
        #
        # @param item [Object] Embedded data item
        # @return [String, nil]
        def reference_id(item)
          return unless item.is_a?(::Hash) && reference_only?(item)

          id = item.values.first
          id if id.is_a?(::String) && id.present?
        end

        # An id in the spelling the column stores it in, nil if it is no uuid.
        #
        # The lookup below answers with the ids as Postgres holds them, so a reference written in
        # another spelling has to be normalised before it can be matched against them. The
        # column's own type does exactly that, down to the nil for something that is no uuid --
        # which then matches nothing, just as a lookup on it would have found nothing.
        #
        # @param id [String, nil]
        # @return [String, nil]
        def stored_id(id)
          DataCycleCore::Thing.type_for_attribute(:id).cast(id)
        end

        # Templates of the content the reference-only items point at, keyed by id.
        #
        # Resolved in one query up front. APIv4 reduces every embedded item to a bare id and
        # validation re-runs once per pushed locale, so looking each one up on its own would cost
        # items x locales single-row queries on exactly the path these references come from.
        #
        # @param data [Array] Embedded data items
        # @return [Hash{String => String}] template_name by id, ids without content absent
        def referenced_template_names(data)
          ids = data.filter_map { |item| stored_id(reference_id(item)) }
          return {} if ids.blank?

          DataCycleCore::Thing.where(id: ids).pluck(:id, :template_name).to_h
        end

        # Whether a reference-only item points at existing content of an allowed template.
        #
        # Takes over the slot's template restriction from the skipped validation: the item
        # names no template, so only the stored record can answer which one it has. Without
        # this the slot would accept any id -- attaching independently managed content that
        # the next push omitting it would destroy, or a dangling id that fails on the
        # content_contents foreign key.
        #
        # Content already embedded elsewhere passes: a second parent does not endanger it, as
        # embedded content is destroyed with check_ancestors and survives being dropped from one
        # parent as long as another still holds it.
        #
        # @param item [Hash] Embedded item data, reference-only as per #reference_only?
        # @param referenced_templates [Hash{String => String}] see #referenced_template_names
        # @param allowed_template_names [Array<String>] Templates the slot accepts
        # @return [Boolean]
        def reference_allowed?(item, referenced_templates, allowed_template_names)
          id = reference_id(item)
          return false if id.nil?

          allowed_template_names.include?(referenced_templates[stored_id(id)])
        end

        # Validates a single embedded item against its template.
        #
        # Supports translation-aware validation by iterating over locales if present.
        #
        # @param item [Hash] Embedded item data
        # @param template [Object] Template object containing schema
        # @return [void]
        def validate_item(item, template)
          if item[:translations].present?
            item[:translations].each do |locale, data|
              next unless data.is_a?(::Hash) && data.present?

              I18n.with_locale(locale) do
                validator_object = DataCycleCore::MasterData::ValidateData.new

                merge_errors(
                  validator_object.validate(
                    data.merge(item[:datahash] || {}),
                    template.schema
                  )
                )
              end
            end
          else
            validator_object = DataCycleCore::MasterData::ValidateData.new
            merge_errors(
              validator_object.validate(
                item.key?(:datahash) ? item[:datahash] : item,
                template.schema
              )
            )
          end
        end

        # Validates classification conflicts within embedded items.
        #
        # Ensures that classification values do not overlap across items.
        #
        # @param values [Array<Hash>] Embedded values
        # @param _template_hash [Hash] Unused template configuration
        # @return [void]
        def classifications(values, _template_hash)
          classification_keys = DataCycleCore.features.dig(:publication_schedule, :classification_keys)

          return if values.blank? || classification_keys.blank?

          classification_key = classification_keys.first
          parsed_values = values.dc_deep_dup.filter_map { |item|
            next unless item.is_a?(::Hash) && item.present?

            item = item['datahash'] if item.key?('datahash')
            item
          }.pluck(classification_key)

          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.classification_conflict' } if
            parsed_values.each_with_index.any? do |item, index|
              parsed_values[(index + 1)..].any? do |item2|
                Array.wrap(item).intersect?(Array.wrap(item2))
              end
            end
        end

        # Validates minimum number of embedded items.
        #
        # @param data [Array<Hash>] Embedded items
        # @param value [Integer] Minimum required count
        # @return [void]
        def min(data, value)
          return unless data.size < value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min_ref',
            substitutions: {
              data: data.size,
              value:
            }
          }
        end

        # Validates maximum number of embedded items.
        #
        # @param data [Array<Hash>] Embedded items
        # @param value [Integer] Maximum allowed count
        # @return [void]
        def max(data, value)
          return unless data.size > value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.max_ref',
            substitutions: {
              data: data.size,
              value:
            }
          }
        end
      end
    end
  end
end
