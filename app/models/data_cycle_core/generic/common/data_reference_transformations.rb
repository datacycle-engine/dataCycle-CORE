# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DataReferenceTransformations
        extend Transformations::TransformationUtilities

        ExternalReference = Struct.new(:reference_type, :external_source_id, :external_key)

        ClassificationNameReference = Struct.new(:tree_name, :classification_name) do
          def classification_path
            [tree_name, classification_name]
          end
        end

        ClassificationUriReference = Struct.new(:tree_name, :uri) do
          def classification_identifier
            [tree_name, uri]
          end
        end

        def self.add_external_content_references(data, property_name, external_source_id, key_resolver)
          add_reference(data, property_name, key_resolver) do |key|
            ExternalReference.new(:content, external_source_id, key)
          end
        end

        def self.get_external_content_references(data, external_source_id, key_resolver)
          get_reference(data, key_resolver) do |key|
            ExternalReference.new(:content, external_source_id, key)
          end
        end

        def self.add_external_schedule_references(data, property_name, external_source_id, key_resolver)
          add_reference(data, property_name, key_resolver) do |key|
            ExternalReference.new(:schedule, external_source_id, key)
          end
        end

        def self.get_external_schedule_references(data, external_source_id, key_resolver)
          get_reference(data, key_resolver) do |key|
            ExternalReference.new(:schedule, external_source_id, key)
          end
        end

        def self.add_external_classification_references(data, property_name, external_source_id, key_resolver)
          add_reference(data, property_name, key_resolver) do |key|
            ExternalReference.new(:classification, external_source_id, key)
          end
        end

        def self.add_uc_references(data, external_source_id, key_resolver)
          add_external_classification_references(data, 'universal_classifications', external_source_id, key_resolver)
        end

        # only works for flat trees!!!
        def self.add_classification_name_references(data, property_name, tree_name, key_resolver, name_mapping_table = ->(v) { v })
          add_reference(data, property_name, key_resolver) do |key|
            ClassificationNameReference.new(tree_name, name_mapping_table.to_proc.call(key))
          end
        end

        # only works for flat trees!!!
        def self.get_classification_name_references(data, tree_name, key_resolver, name_mapping_table = ->(v) { v })
          get_reference(data, key_resolver) do |key|
            ClassificationNameReference.new(tree_name, name_mapping_table.to_proc.call(key))
          end
        end

        def self.add_classification_uri_references(data, property_name, tree_name, key_resolver, uri_mapping_table = ->(v) { v })
          add_reference(data, property_name, key_resolver) do |key|
            ClassificationUriReference.new(tree_name, uri_mapping_table.to_proc.call(key))
          end
        end

        def self.get_reference(data, key_resolver, &)
          reference_keys = if key_resolver.respond_to?(:to_proc)
                             Array.wrap(key_resolver.to_proc.call(data)) || []
                           else
                             Array(resolve_attribute_path(data, key_resolver))
                           end

          reference_keys.map(&)
        end

        def self.add_reference(data, property_name, key_resolver, &)
          references = get_reference(data, key_resolver, &)

          if property_name == 'universal_classifications'
            data.merge({ property_name => (data[property_name] || []) + references })
          else
            data.merge({ property_name => references })
          end
        end

        def self.resolve_references(data)
          collected_references = collect_references(data)

          external_reference_mapping_table = create_external_reference_mapping_table(collected_references)
          classification_path_mapping_table = create_classification_path_mapping_table(collected_references)
          classification_uri_mapping_table = create_classification_uri_mapping_table(collected_references)
          classification_mapping_table = classification_path_mapping_table.merge(classification_uri_mapping_table)

          replace_references(data, external_reference_mapping_table, classification_mapping_table)
        end

        def self.collect_references(data)
          if data.is_a?(ExternalReference) || data.is_a?(ClassificationNameReference) || data.is_a?(ClassificationUriReference)
            data
          elsif data.is_a?(Hash)
            data.values.map { |v| collect_references(v) }.flatten
          elsif data.is_a?(Array)
            data.map { |v| collect_references(v) }.flatten
          else
            []
          end
        end

        def self.create_external_reference_mapping_table(collected_references)
          collected_external_references = collected_references.select do |ref|
            ref.is_a?(ExternalReference)
          end

          collected_external_references.map(&:reference_type).uniq.map { |reference_type|
            {
              reference_type => collected_external_references.map(&:external_source_id).uniq.map { |external_source_id|
                external_keys = collected_external_references.select { |ref|
                  ref.external_source_id == external_source_id
                }.map(&:external_key)

                {
                  external_source_id => load_data(reference_type, external_source_id, external_keys.compact)
                }
              }.reduce(&:merge)
            }
          }.reduce(&:merge)
        end

        def self.create_classification_path_mapping_table(collected_references)
          load_classifications_by_path(
            collected_references.select { |ref|
              ref.is_a?(ClassificationNameReference)
            }.map(&:classification_path)
          )
        end

        def self.create_classification_uri_mapping_table(collected_references)
          load_classifications_by_uri(
            collected_references.select { |ref|
              ref.is_a?(ClassificationUriReference)
            }.map(&:classification_identifier)
          )
        end

        def self.replace_references(data, external_reference_mapping_table, classification_mapping_table)
          if data.is_a?(ExternalReference)
            external_reference_mapping_table.dig(data.reference_type, data.external_source_id, data.external_key&.to_s)
          elsif data.is_a?(ClassificationNameReference)
            classification_mapping_table[data.classification_path]
          elsif data.is_a?(ClassificationUriReference)
            classification_mapping_table[data.uri]
          elsif data.is_a?(Hash)
            data.transform_values { |v| replace_references(v, external_reference_mapping_table, classification_mapping_table) }
          elsif data.is_a?(Array)
            data.map { |v| replace_references(v, external_reference_mapping_table, classification_mapping_table) }.compact.uniq
          else
            data
          end
        end

        def self.load_data(reference_type, external_source_id, external_keys)
          case reference_type
          when :content
            load_things(external_source_id, external_keys)
          when :classification
            load_classifications(external_source_id, external_keys)
          when :schedule
            load_schedules(external_source_id, external_keys)
          else
            raise "Unknown reference type: #{reference_type}"
          end
        end

        def self.load_things(external_source_id, external_key)
          (
            DataCycleCore::Thing.where(external_source_id:, external_key:).pluck(:external_key, :id) +
            DataCycleCore::ExternalSystemSync.where(external_system_id: external_source_id, external_key:)
                                             .pluck(:external_key, :syncable_id)
          ).uniq.to_h
        end

        def self.load_schedules(external_source_id, external_keys)
          DataCycleCore::Schedule.where(external_source_id:, external_key: external_keys)
                                 .pluck(:external_key, :id).to_h
        end

        def self.load_classifications(external_source_id, external_keys)
          DataCycleCore::Classification.where(external_source_id:, external_key: external_keys)
                                       .pluck(:external_key, :id).to_h
        end

        def self.load_classifications_by_uri(classification_identifier)
          DataCycleCore::ClassificationAlias.for_tree(classification_identifier.pluck(0).uniq)
                                            .where(uri: classification_identifier.pluck(1).uniq)
                                            .primary_classifications
                                            .pluck(:uri, :id).to_h
        end

        def self.load_classifications_by_path(classification_paths)
          return {} if classification_paths.empty?

          preloadable_classification_trees = if instance_variable_defined?(:@preloadable_classification_trees)
                                               classification_paths.map(&:first) & (Array.wrap(instance_variable_get(:@preloadable_classification_trees)))
                                             else
                                               []
                                             end

          @peloaded_mappings ||= {}

          @peloaded_mappings.merge!(
            DataCycleCore::ClassificationAlias::Path.where(
              'full_path_names[ARRAY_UPPER(full_path_names, 1)] IN (?)',
              preloadable_classification_trees - @peloaded_mappings.keys.map(&:first)
            ).joins(classification_alias: :primary_classification)
              .includes(classification_alias: :primary_classification)
              .to_h { |path| [path.full_path_names.reverse, path.classification_alias.primary_classification.id] }
          )

          if (classification_paths - @peloaded_mappings.keys).empty?
            @peloaded_mappings
          else
            @peloaded_mappings.merge(
              (classification_paths - @peloaded_mappings.keys).map { |classification_path|
                DataCycleCore::ClassificationAlias::Path.where(full_path_names: classification_path.reverse)
              }.reduce(:or)
                .joins(classification_alias: :primary_classification)
                .includes(classification_alias: :primary_classification)
                .to_h { |path| [path.full_path_names.reverse, path.classification_alias.primary_classification.id] }
            )
          end
        end

        def self.clear_peloaded_mappings
          @peloaded_mappings = {}
        end
      end
    end
  end
end
