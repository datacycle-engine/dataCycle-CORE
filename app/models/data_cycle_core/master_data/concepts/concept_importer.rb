# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Concepts
      class ConceptImporter
        # only Inhaltstypen gets be deduplicated and merged, all others are overwritten
        DEDUPLICATE = ['Inhaltstypen'].freeze
        MERGE = ['Inhaltstypen'].freeze

        attr_reader :errors, :counts

        def initialize(paths: nil)
          @paths = paths.presence || [DataCycleCore.default_template_paths, DataCycleCore.template_path].flatten.uniq.compact
          @errors = []
          @concept_schemes = {}
          @concept_mappings = {}
          @counts = {
            concept_schemes: 0,
            concepts: 0,
            concept_mappings: 0
          }

          load_concepts
          load_concept_mappings
        end

        def import
          return unless valid?

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

            insert_concept_schemes
            raise ActiveRecord::Rollback if @errors.present?

            insert_concepts
            raise ActiveRecord::Rollback if @errors.present?

            insert_concept_mappings
            raise ActiveRecord::Rollback if @errors.present?
          end
        end

        def valid?
          @errors.blank?
        end

        # rubocop:disable Rails/Output
        def render_errors
          return if @errors.blank?

          puts AmazingPrint::Colors.red('the following errors were encountered during import:')
          ap @errors
        end
        # rubocop:enable Rails/Output

        private

        def insert_concept_schemes
          return if @concept_schemes.blank?

          ctls = @concept_schemes.values
          existing = DataCycleCore::ClassificationTreeLabel.with_deleted.where(external_key: ctls.pluck(:external_key)).pluck(:external_key)
          to_insert = @concept_schemes.reject { |_, v| v[:external_key]&.in?(existing) }

          return if to_insert.blank?

          DataCycleCore::ClassificationTreeLabel.insert_all(
            to_insert.values.map { |cs| cs.slice(:name, :internal, :visibility, :external_key, :external_source_id) }
          )

          @counts[:concept_schemes] = to_insert.size
        rescue StandardError => e
          @errors.push("error inserting concept_schemes => #{e}")
        end

        def insert_concepts
          return if @concept_schemes.blank?

          loaded_cs = DataCycleCore::ClassificationTreeLabel.where(name: @concept_schemes.keys).index_by(&:name)

          @concept_schemes.each_value do |cs|
            concept_scheme = loaded_cs[cs[:name]]

            next if concept_scheme.blank? || concept_scheme.external_source_id != cs[:external_source_id]
            next if cs[:concepts].blank?

            existing = DataCycleCore::ClassificationAlias.with_deleted.where(external_source_id: cs[:external_source_id], external_key: cs[:concepts].pluck(:external_key)).pluck(:external_key)
            to_insert = cs[:concepts].reject { |c| existing.include?(c[:external_key]) }

            next if to_insert.blank?

            concept_scheme.insert_all_external_classifications(to_insert)
            @counts[:concepts] += to_insert.size
          rescue StandardError => e
            @errors.push("error inserting concepts for #{cs[:name]} => #{e}")
          end
        end

        def insert_concept_mappings
          return if @concept_mappings.blank?

          new_groups = []
          full_paths = (@concept_mappings.keys + @concept_mappings.values).flatten
          concepts = DataCycleCore::ClassificationAlias
            .includes(:primary_classification)
            .by_full_paths(full_paths)
            .each_with_object({}) do |ca, h|
            h[ca.full_path] ||= []
            h[ca.full_path] << { classification_alias_id: ca.id, classification_id: ca.primary_classification&.id }
          end

          @concept_mappings.each do |key, value|
            next unless concepts.key?(key)

            Array.wrap(value).each do |v|
              next unless concepts.key?(v)

              parents = concepts[key]
              children = concepts[v]

              parents.each do |parent|
                children.each do |child|
                  new_groups.push({ classification_alias_id: parent[:classification_alias_id], classification_id: child[:classification_id], created_at: Time.zone.now, updated_at: Time.zone.now }) # created_at and updated_at required for primary_classification in tests
                end
              end
            end
          end

          return if new_groups.blank?

          result = DataCycleCore::ClassificationGroup.insert_all(new_groups, unique_by: :classification_groups_ca_id_c_id_uq_idx)

          @counts[:concept_mappings] = result.count
        end

        def load_concept_mappings
          @paths.each do |path|
            load_concept_mappings_from_path(path)
          end

          @concept_mappings = @concept_mappings&.values&.reduce(&:merge)&.compact
        end

        def load_concepts
          @paths.each do |path|
            load_concepts_from_path(path)
          end

          post_transformation!

          @concept_schemes
        end

        def load_concept_mappings_from_path(file_path)
          Dir[File.join(file_path, 'classification_mappings.yml')].each do |path|
            data = YAML.safe_load(File.open(path.to_s), permitted_classes: [Symbol], aliases: true)

            append_concept_mappings!(data)
          rescue StandardError => e
            @errors.push("error loading mappings YML File (#{path}) => #{e.message}")
          end
        end

        def append_concept_mappings!(data)
          return if data.blank?

          @concept_mappings.deep_merge!(data) do |_k, v1, v2|
            if (v1.is_a?(::Array) || v1.is_a?(String)) && (v2.is_a?(::Array) || v2.is_a?(String))
              Array.wrap(v1) + Array.wrap(v2)
            else
              v2
            end
          end
        end

        def load_concepts_from_path(file_path)
          Dir[File.join(file_path, 'classifications.yml')].each do |path|
            data = Array.wrap(YAML.safe_load(File.open(path.to_s), permitted_classes: [Symbol], aliases: true))

            append_concept_schemes!(data)
          rescue StandardError => e
            @errors.push("error loading YML File (#{path}) => #{e.message}")
          end
        end

        def append_concept_schemes!(data)
          data.each do |concept_scheme_data|
            concept_scheme = parse_concept_scheme(concept_scheme_data)
            key = concept_scheme[:name]

            if MERGE.include?(key) && @concept_schemes.key?(key)
              existing_concepts = @concept_schemes[key][:concepts]
              @concept_schemes[key].merge!(concept_scheme)
              @concept_schemes[key][:concepts] = existing_concepts + concept_scheme[:concepts]
            else
              @concept_schemes[key] = concept_scheme
            end

            deduplicate_concepts!(@concept_schemes[key][:concepts]) if DEDUPLICATE.include?(key)
          end
        end

        def deduplicate_concepts!(concepts)
          concepts.reverse!
          concepts.uniq! { |c| c[:name] }
          concepts.reverse!
        end

        def parse_concept_scheme(data)
          if data.key?('name')
            parse_concept_scheme_hash(data)
          else
            parse_concept_scheme_legacy(data)
          end
        end

        def parse_concept_scheme_hash(data)
          cs_data = data.slice('name', 'internal', 'visibility', 'external_source', 'external_key')
          cs_data['external_key'] = cs_data['name'] if cs_data['external_key'].blank?
          cs_data['concepts'] = parse_concepts(data['concepts'], cs_data['name'])
          cs_data.symbolize_keys
        end

        def parse_concept_scheme_legacy(data)
          name = data.keys.first
          internal = false

          if name.starts_with?('$$') # '$$' prefix for interal concept_schemes
            name = name[2..-1]
            internal = true
          end

          split_data = name.split('|').map(&:squish)
          name = split_data[0]
          visibility = split_data[1]&.split(',')&.map(&:squish) || []

          {
            name: name,
            internal: internal,
            visibility: visibility,
            external_key: name,
            concepts: parse_concepts(data.values.first, name)
          }
        end

        def parse_concepts(data, parent_key = nil)
          concepts = []
          return concepts if data.blank?

          data.map do |concept|
            if concept.is_a?(::Hash) && concept.key?('name')
              concepts.concat(parse_concept_hash(concept, parent_key))
            else
              concepts.concat(parse_concept_legacy(concept, parent_key))
            end
          end

          concepts
        end

        def concept_external_key(data, parent_key)
          internal_name = data['name']
          internal_name = data['name_i18n'].values_at(*I18n.available_locales).compact.first if data.key?('name_i18n')
          [parent_key, internal_name].compact.join(' > ')
        end

        def parse_concept_hash(data, parent_key = nil)
          c_data = data.slice('name', 'internal', 'assignable', 'uri', 'description', 'external_key')
          c_data['name_i18n'] = c_data.delete('name').symbolize_keys if c_data['name'].is_a?(::Hash)
          c_data['description_i18n'] = c_data.delete('description').symbolize_keys if c_data['description'].is_a?(::Hash)
          c_data['external_key'] = concept_external_key(c_data, parent_key) if c_data['external_key'].blank?
          c_data['parent_external_key'] = parent_key

          child_concepts = parse_concepts(data['concepts'], c_data['external_key'])

          [c_data.symbolize_keys] + child_concepts
        end

        def parse_concept_legacy(data, parent_key = nil)
          name = data.is_a?(::Hash) ? data.keys.first : data
          internal = false

          if name.starts_with?('$$') # '$$' prefix for interal concepts
            name = name[2..-1]
            internal = true
          end

          # extract uri
          split_data = name.split('**').map(&:squish)
          uri = split_data[1]

          # extract description
          split_data = split_data[0].split('|').map(&:squish)
          name = split_data[0]
          description = split_data[1]
          external_key = [parent_key, name].compact.join(' > ')

          concept = {
            name: name,
            description: description,
            internal: internal,
            uri: uri,
            external_key: external_key,
            parent_external_key: parent_key
          }
          child_concepts = data.is_a?(::Hash) ? parse_concepts(data.values.first, external_key) : []

          [concept] + child_concepts
        end

        def post_transformation!
          external_sources = DataCycleCore::ExternalSystem.by_names_or_identifiers(@concept_schemes.values.pluck(:external_source).compact)
          es_mapping = external_sources.to_h { |es| [es.name, es.id] }.merge(external_sources.to_h { |es| [es.identifier, es.id] })

          @concept_schemes.each_value do |cs|
            cs[:visibility] = DataCycleCore.default_classification_visibilities if cs[:visibility].blank? || cs[:visibility].include?('all')
            cs[:internal] = false if cs[:internal].nil?
            es_id = es_mapping[cs.delete(:external_source)] if cs[:external_source].present?
            cs[:external_source_id] = es_id
            cs[:concepts].each.with_index do |c, index|
              c[:order_a] = index
              c[:external_source_id] = es_id if es_id.present?
            end
          end
        end
      end
    end
  end
end
