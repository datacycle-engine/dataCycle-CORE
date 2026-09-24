# frozen_string_literal: true

require 'rake_helpers/parallel_helper'

namespace :dc do
  namespace :classifications do
    namespace :import do
      require 'csv'
      require 'roo'

      # Format: id | parent_id | name
      # Both mapping tasks end here: write the `related` links and fan the side effects out once per
      # concept for the union of its affected contents (per-mapping jobs would collapse under
      # CacheInvalidationDestroyJob's (concept, method) dedup key) - see Concept#mapped_concepts_changed.
      insert_mappings = lambda do |to_insert, errors|
        puts "\nstart inserting ... (#{to_insert.size})"

        inserted = []

        ActiveRecord::Base.transaction do
          ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

          inserted = DataCycleCore::ConceptLink.insert_all(to_insert.uniq, unique_by: :index_concept_links_on_parent_id_and_child_id).pluck('id')
        end

        mapped_ids_by_concept = Hash.new { |h, k| h[k] = [] }
        DataCycleCore::ConceptLink.includes(:parent).where(id: inserted).find_each do |link|
          mapped_ids_by_concept[link.parent] << link.child_id
        end

        mapped_ids_by_concept.each { |concept, mapped_ids| concept.mapped_concepts_changed(mapped_ids) }

        puts
        puts errors.join("\n")
        puts "FINISHED IMPORTING MAPPINGS! (new: #{inserted.size}, duplicates: #{to_insert.size - inserted.size}, errors: #{errors.size})"
      end

      desc 'import classifications from xlsx. Format: id | parent_id | name'
      task :from_xlsx, [:file_path] => :environment do |_, args|
        abort('file_path missing!') if args.file_path.blank?

        file_paths = Dir[args.file_path]
        abort('no files found at this path!') if file_paths.blank?

        concepts = []
        concept_scheme = nil
        classification_count = 0

        file_paths.each do |file_path|
          Roo::Spreadsheet.open(file_path).each_with_pagename do |_name, sheet|
            sheet.each do |row|
              next if row.blank?

              attrs = {
                external_key: row[0].to_s.strip,
                name: row[2].to_s.strip,
                parent_external_key: row[1].to_s.strip
              }.compact_blank

              if attrs[:parent_external_key].blank?
                abort('Multiple ConceptSchemes found') if concept_scheme.present?

                concept_scheme = DataCycleCore::ConceptScheme.find_by(attrs)
                next if concept_scheme

                cs = DataCycleCore::ConceptScheme.upsert_all([attrs], returning: :id)
                concept_scheme = DataCycleCore::ConceptScheme.find_by(id: cs.first['id']) if cs.any?
                next
              end

              abort('ConceptScheme missing before child rows') if concept_scheme.nil?

              attrs[:concept_scheme_external_key] = concept_scheme.external_key
              attrs[:concept_scheme_name] = concept_scheme.name

              concepts << attrs.merge({
                concept_scheme_external_key: concept_scheme.external_key,
                concept_scheme_name: concept_scheme.name
              })

              classification_count += 1
            end
          end
        end
        upserted = concept_scheme.upsert_all_external_concepts(concepts)

        print "imported #{upserted.count} classifications from #{classification_count} rows \n"
      end

      desc 'import mappings CSV file'
      task :mappings_from_csv, [:file_path, :separator] => :environment do |_, args|
        abort('file_path missing!') if args.file_path.blank?

        errors = []
        file_paths = Dir[args.file_path]
        separator = args.separator.presence || ','

        abort('no files found at this path!') if file_paths.blank?

        to_insert = []

        file_paths.each do |file_path|
          file = File.read(file_path)
          data = CSV.parse(file.encode_utf8!, skip_blanks: true, col_sep: separator)
          data.select! { |(ca_path, mapped_ca_path)| ca_path.to_s.include?('>') && mapped_ca_path.to_s.include?('>') }
            .map! { |(ca_path, mapped_ca_path)| [ca_path.to_s.strip, mapped_ca_path.to_s.strip] }

          cas = DataCycleCore::Concept.by_full_paths(data.uniq.flatten)

          data.uniq.each do |(ca_path, mapped_ca_path)|
            ca = cas.select { |c_alias| c_alias.full_path == ca_path }
            if ca.blank?
              errors << "concept not found (#{File.basename(file_path)}: '#{ca_path}' => '#{mapped_ca_path}')"
              print 'x'
              next
            end

            mapped_ca = cas.select { |c_alias| c_alias.full_path == mapped_ca_path }
            if mapped_ca.blank?
              errors << "mapped concept not found (#{File.basename(file_path)}: '#{ca_path}' => '#{mapped_ca_path}')"
              print 'x'
              next
            end

            ca.each do |original|
              mapped_ca.each do |mapped|
                to_insert.push({ parent_id: original.id, child_id: mapped.id, link_type: DataCycleCore::ConceptLink::LINK_TYPE_RELATED })
                print('.')
              end
            end
          end
        end

        abort('no mappings found!') if to_insert.blank?

        insert_mappings.call(to_insert, errors)
      end

      desc 'import translations from XLSX or CSV file'
      task :translations_from_spreadsheet, [:locale, :file_path, :use_external_key] => :environment do |_, args|
        abort('locale missing!') if args.locale.blank?
        abort('locale not enabled in this system!') if I18n.available_locales.exclude?(args.locale.to_sym)
        abort('file_path missing!') if args.file_path.blank?

        errors = []
        # not the whole connection pool: this task also runs through RunTaskJob, and there it shares
        # its process with the other jobs of a multi-threaded worker (see WorkerPool)
        pool = Concurrent::FixedThreadPool.new(DataCycleCore::WorkerPool.default_num_workers)
        futures = []
        file_paths = Dir[args.file_path]
        use_external_key = args.use_external_key || false

        abort('no files found at this path!') if file_paths.blank?

        file_paths.each do |file_path|
          Roo::Spreadsheet.open(file_path).each_with_pagename do |_name, sheet|
            sheet.each do |row|
              next if row.blank?

              ca_identifier = row[0].to_s.strip # ca_identifier can either be the full_classifiation_path or the external_key
              ca_translation = row[1].to_s.strip

              next unless ca_translation.present? && (ca_identifier.include?('>') || use_external_key)

              ParallelHelper.run_in_parallel(futures, pool) do
                ca = if use_external_key
                       DataCycleCore::Concept.find_by(external_key: ca_identifier)
                     else
                       DataCycleCore::Concept.custom_find_by_full_path(ca_identifier)
                     end

                if ca.nil?
                  errors << "concept not found (#{ca_identifier})"
                  print 'x'
                  next
                end

                I18n.with_locale(args.locale) do
                  ca.prevent_webhooks = true
                  ca.update(name: ca_translation.squish)
                  print ca.name_i18n_previously_changed? ? '+' : '.'
                end
              rescue StandardError
                errors << "unkown error occurred (#{ca_identifier})"
                print 'x'
              end
            end

            futures.each(&:wait!)
          end
        end

        puts
        puts errors.join("\n")
        puts "FINISHED IMPORTING TRANSLATIONS! (#{errors.size} errors)"
      end

      # Creates classification mappings between two trees by matching concept names (internal_name).
      # The target tree is expected to be a (usually smaller) subset of the source tree, so we index
      # the source tree once and iterate the target tree, mapping each matching source concept onto
      # its target counterpart.
      # End result in the view: each matched target-tree classification is shown as a "child" of the
      # corresponding source-tree classification.
      # Idempotent: re-running only adds mappings that don't exist yet.
      desc 'map concepts between two classification trees by matching name (internal_name); ' \
           'args: source_tree_label, target_tree_label (target is treated as a subset of source)'
      task :mappings_by_name, [:source_tree_label, :target_tree_label] => :environment do |_, args|
        abort('source_tree_label and target_tree_label are required!') if args.source_tree_label.blank? || args.target_tree_label.blank?

        source_tree_label = args.source_tree_label.strip
        target_tree_label = args.target_tree_label.strip

        abort('source_tree_label and target_tree_label must differ!') if source_tree_label == target_tree_label
        abort("source tree_label '#{source_tree_label}' not found!") unless DataCycleCore::ConceptScheme.exists?(name: source_tree_label)
        abort("target tree_label '#{target_tree_label}' not found!") unless DataCycleCore::ConceptScheme.exists?(name: target_tree_label)

        errors = []
        to_insert = []

        # index the (larger) source tree by internal_name => [concept_id, ...]
        source_concept_ids_by_name = Hash.new { |h, k| h[k] = [] }
        DataCycleCore::Concept.for_tree(source_tree_label).find_each do |source_concept|
          source_concept_ids_by_name[source_concept.internal_name] << source_concept.id
        end

        # iterate the (smaller) target tree and map each matching source concept onto it
        DataCycleCore::Concept.for_tree(target_tree_label).find_each do |target_concept|
          source_concept_ids = source_concept_ids_by_name[target_concept.internal_name]
          if source_concept_ids.blank?
            errors << "no match in '#{source_tree_label}' for '#{target_concept.internal_name}'"
            print 'x'
            next
          end

          source_concept_ids.each do |source_concept_id|
            to_insert.push({ parent_id: source_concept_id, child_id: target_concept.id, link_type: DataCycleCore::ConceptLink::LINK_TYPE_RELATED })
            print '.'
          end
        end

        abort("\nno matching concepts found between '#{source_tree_label}' and '#{target_tree_label}'!") if to_insert.blank?

        insert_mappings.call(to_insert, errors)
      end
    end

    namespace :update do
      desc 'move classification from one path to another z.B Inhaltstypen|Bild,Inhaltstypen|Assets|Bild'
      task :move_from_to, [:from_path, :to_path, :destroy_children, :prevent_webhooks] => [:environment] do |_, args|
        from_path = args.from_path&.split('|')&.map { |s| s.delete('"') }
        to_path = args.to_path&.split('|')&.map { |s| s.delete('"') }

        destroy_children = args.destroy_children&.to_s == 'true'

        abort('ERROR: Missing from- or to_path') if from_path.blank? || to_path.blank?

        from_ca = from_path.first.uuid? ? DataCycleCore::Concept.find_by(id: from_path.first) : DataCycleCore::Concept.includes(:concept_path).find_by(concept_paths: { full_path_names: from_path.reverse })

        abort('ERROR: from Concept not found') if from_ca.nil?

        from_ca.prevent_webhooks = args.prevent_webhooks&.to_s == 'true'

        begin
          new_ca = from_ca.move_to_path(to_path, destroy_children:)
        rescue DataCycleCore::Error::AmbiguousClassificationExternalSystemError => e
          # destroy_children merges every descendant into the target, so a child whose external
          # identity the target cannot answer to refuses -- the transaction is already rolled back,
          # only the message is missing
          abort("ERROR: #{e.message}")
        end

        abort('ERROR: error moving to new path') unless new_ca.is_a?(DataCycleCore::Concept)

        puts('WARNING: classifications moved to another tree! Check if relation in DataCycleCore::ConceptContent needs to be updated!') if from_path.first != to_path.first

        puts("SUCCESS: successfully moved classification to new path: #{new_ca.reload.full_path}")
      end

      desc 'sort tree alphabetically'
      task :sort_alphabetically, [:tree_labels] => [:environment] do |_, args|
        abort('tree_labels missing!') if args.tree_labels.blank?

        concept_schemes = DataCycleCore::ConceptScheme.where(name: args.tree_labels.split('|').map(&:strip))

        abort('tree_labels not found!') if concept_schemes.blank?

        concept_schemes.each(&:sort_concepts_alphabetically!)
      end
    end

    namespace :merge do
      desc 'create distinct classification tree with mappings'
      task :create_distinct_tree, [:from_tree_label, :to_tree_label, :map_only_leafs] => [:environment] do |_, args|
        from_tree_label_name = args.from_tree_label.strip
        map_only_leafs = args.map_only_leafs&.to_s == 'true'
        to_tree_label_name = args.to_tree_label&.strip.presence || "#{from_tree_label_name} (Distinct)"

        abort('missing from_tree_label!') if from_tree_label_name.blank?
        abort('missing to_tree_label!') if to_tree_label_name.blank?

        from_tree_label = DataCycleCore::ConceptScheme.find_by!(name: from_tree_label_name)
        to_tree_label = DataCycleCore::ConceptScheme.find_or_create_by(name: to_tree_label_name) do |tree_label|
          tree_label.visibility = DataCycleCore.default_classification_visibilities
        end

        mappings = []
        classifications = from_tree_label
          .concepts
          .preload(:concept_path)
          .group_by { |ca| ca.concept_path&.full_path_names&.reverse&.drop(1) }
          .map { |k, v|
            next if k.include?(nil)

            mappings.concat(v.map { |ca| { path: ([to_tree_label.name] + k).join(' > '), concept_id: ca.id } }.uniq)

            {
              name: k.last,
              name_i18n: v.pluck(:name_i18n).compact_blank.reduce(&:merge),
              path: k
            }
          }.compact_blank

        puts "upserting #{classifications.size} classifications to new tree_label"

        tmp = Time.zone.now
        to_tree_label.insert_all_concepts_by_path(classifications)

        if map_only_leafs
          puts 'mapping only leaf classifications...'
          mappings.select! do |m|
            mappings.none? { |other| other[:path].include?("#{m[:path]} >") }
          end
        end

        aliases = DataCycleCore::Concept.by_full_paths(mappings.pluck(:path).uniq).to_h { |ca| [ca.full_path, ca.id] }
        new_links = mappings.map { |m| { parent_id: aliases[m[:path]], child_id: m[:concept_id], link_type: DataCycleCore::ConceptLink::LINK_TYPE_RELATED } }

        DataCycleCore::ConceptLink.insert_all(new_links, unique_by: :index_concept_links_on_parent_id_and_child_id, returning: false)

        puts AmazingPrint::Colors.green("[DONE] finished upserting #{mappings.size} mappings in #{Time.zone.now - tmp}s.")
      end
    end

    desc 'Delete Classification Tree Label'
    task :destroy_classification_tree_label, [:tree_label_key] => :environment do |_, args|
      tree_label_key = args[:tree_label_key]

      tree = DataCycleCore::ConceptScheme.find_by(external_key: tree_label_key)
      return if tree.nil?

      tree.concepts.find_each do |concept|
        concept.mapped_concept_links.find_each do |link|
          ActiveRecord::Base.transaction do
            ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
            link.destroy
            print('.')
          end
        end

        ActiveRecord::Base.transaction do
          ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
          concept.concept_contents.delete_all
          print('.')
        end
      end

      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')
        DataCycleCore::ConceptScheme.find_by(external_key: tree_label_key)&.destroy
      end
    end

    desc 'outputs all stored filters that use the provided concept_id or tree_id'
    task :in_stored_filter, [:concept_id_or_concept_scheme_id, :include_children] => [:environment] do |_, args|
      id = args.concept_id_or_concept_scheme_id
      abort('concept_id or tree_id missing!') if id.blank?

      concept = DataCycleCore::Concept.find_by(id:)
      tree = DataCycleCore::ConceptScheme.find_by(id:) if concept.nil?

      abort('concept_id or tree_id not found!') if concept.nil? && tree.nil?

      if tree.present?
        ca_ids = DataCycleCore::Concept.for_tree(tree.name).pluck(:id)
        puts "Found #{ca_ids.size} concept_ids for concept_scheme_id: #{id} (#{tree.name})"
      elsif concept.present?
        include_children = args.include_children == 'true'

        ca_children_ids = []
        if include_children
          child_query = <<~SQL.squish
            SELECT * FROM concept_paths
            WHERE '#{id}' = ANY(ancestor_ids);
          SQL
          ca_children = ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.send(:sanitize_sql_array, [child_query])
          )
          ca_children_ids = ca_children.pluck('id')
          puts "Found #{ca_children.ntuples} children for concept_id: #{id} (#{concept.full_path})"
        end

        ca_ids = [id] + ca_children_ids
      end

      found_stored_filters = []

      ca_ids.each do |ca_id|
        stored_filters = DataCycleCore::StoredFilter.where('parameters::TEXT ILIKE ?', "%#{ca_id}%").named.order(updated_at: :desc).select(:id, :name, :updated_at, :api)
        concept = DataCycleCore::Concept.find_by(id:)
        next if concept.nil? || stored_filters.empty?

        found_stored_filters << stored_filters.pluck(:id)
        puts "Found #{stored_filters.size} stored_filters for concept_id: #{ca_id} (#{concept.full_path})"
        pp stored_filters.as_json(only: [:id, :name, :updated_at, :api]) if stored_filters.size.positive?
      end

      found_stored_filters = found_stored_filters.flatten.uniq

      puts 'SUMMARY:'
      puts "Found #{found_stored_filters.size} stored_filters"
      puts found_stored_filters if found_stored_filters.size.positive?
    end
  end
end
