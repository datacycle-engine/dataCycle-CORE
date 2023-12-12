# frozen_string_literal: true

require 'rake_helpers/parallel_helper'

namespace :dc do
  namespace :classifications do
    namespace :import do
      require 'csv'
      require 'roo'

      desc 'import mappings from XLSX or CSV file'
      task :mappings_from_spreadsheet, [:file_path] => :environment do |_, args|
        abort('file_path missing!') if args.file_path.blank?

        updated_at = Time.zone.now
        errors = []
        file_paths = Dir[args.file_path]

        abort('no files found at this path!') if file_paths.blank?

        to_insert = []

        file_paths.each do |file_path|
          data = Roo::Spreadsheet.open(file_path)
          sheet = data.sheet(data.sheets.first)
          sheet.each do |row|
            next if row.blank?

            ca_path = row[0].to_s.strip
            mapped_ca_path = row[1].to_s.strip

            next unless ca_path.include?('>') && mapped_ca_path.include?('>')

            ca = DataCycleCore::ClassificationAlias.custom_find_by_full_path(ca_path)
            if ca.nil?
              errors << "classification_alias not found (#{File.basename(file_path)} => #{ca_path})"
              print 'x'
              next
            end

            mapped_ca = DataCycleCore::ClassificationAlias.custom_find_by_full_path!(mapped_ca_path)
            raise ActiveRecord::RecordNotFound if mapped_ca.primary_classification.nil?

            to_insert.push({ classification_id: mapped_ca.primary_classification.id, classification_alias_id: ca.id, updated_at: })

            print('.')
          rescue ActiveRecord::RecordNotFound
            errors << "mapped classification_alias not found (#{File.basename(file_path)} => #{mapped_ca_path})"
            print 'x'
          end
        end

        puts "\nstart inserting ... (#{to_insert.size})"
        inserted = DataCycleCore::ClassificationGroup.insert_all(to_insert.uniq, unique_by: :classification_groups_ca_id_c_id_uq_idx).pluck('id')

        DataCycleCore::ClassificationGroup.includes(:classification, :classification_alias).where(id: inserted).find_each do |group|
          group.classification_alias.send(:classifications_added, group.classification)
        end

        duplicates = to_insert.size - inserted.size

        puts
        puts errors.join("\n")
        puts "FINISHED IMPORTING MAPPINGS! (new: #{inserted.size}, duplicates: #{duplicates}, errors: #{errors.size})"
      end

      desc 'import translations from XLSX or CSV file'
      task :translations_from_spreadsheet, [:locale, :file_path] => :environment do |_, args|
        abort('locale missing!') if args.locale.blank?
        abort('locale not enabled in this system!') if I18n.available_locales.exclude?(args.locale.to_sym)
        abort('file_path missing!') if args.file_path.blank?

        errors = []
        pool = Concurrent::FixedThreadPool.new(ActiveRecord::Base.connection_pool.size - 1)
        futures = []
        file_paths = Dir[args.file_path]

        abort('no files found at this path!') if file_paths.blank?

        file_paths.each do |file_path|
          Roo::Spreadsheet.open(file_path).each_with_pagename do |_name, sheet|
            sheet.each do |row|
              next if row.blank?

              ca_path = row[0].to_s.strip
              ca_translation = row[1].to_s.strip

              next unless ca_path.include?('>') && ca_translation.present?

              ParallelHelper.run_in_parallel(futures, pool) do
                ca = DataCycleCore::ClassificationAlias.custom_find_by_full_path(ca_path)

                if ca.nil?
                  errors << "classification_alias not found (#{ca_path})"
                  print 'x'
                  next
                end

                I18n.with_locale(args.locale) do
                  ca.prevent_webhooks = true
                  ca.update(name: ca_translation.squish)
                  print ca.name_i18n_previously_changed? ? '+' : '.'
                end
              rescue StandardError
                errors << "unkown error occurred (#{ca_path})"
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
    end

    namespace :update do
      desc 'move classification from one path to another z.B Inhaltstypen|Bild,Inhaltstypen|Assets|Bild'
      task :move_from_to, [:from_path, :to_path, :destroy_children, :prevent_webhooks] => [:environment] do |_, args|
        from_path = args.from_path&.split('|')&.map { |s| s.delete('"') }
        to_path = args.to_path&.split('|')&.map { |s| s.delete('"') }

        destroy_children = args.destroy_children&.to_s == 'true'

        abort('ERROR: Missing from- or to_path') if from_path.blank? || to_path.blank?

        from_ca = from_path.first.uuid? ? DataCycleCore::ClassificationAlias.find_by(id: from_path.first) : DataCycleCore::ClassificationAlias.includes(:classification_alias_path).find_by(classification_alias_paths: { full_path_names: from_path.reverse })

        abort('ERROR: from ClassificationAlias not found') if from_ca.nil?

        from_ca.prevent_webhooks = args.prevent_webhooks&.to_s == 'true'

        new_ca = from_ca.move_to_path(to_path, destroy_children)

        abort('ERROR: error moving to new path') unless new_ca.is_a?(DataCycleCore::ClassificationAlias)

        puts('WARNING: classifications moved to another tree! Check if relation in DataCycleCore::ClassificationContent needs to be updated!') if from_path.first != to_path.first

        puts("SUCCESS: successfully moved classification to new path: #{new_ca.reload.full_path}")
      end

      desc 'sort tree alphabetically'
      task :sort_alphabetically, [:tree_labels] => [:environment] do |_, args|
        abort('tree_labels missing!') if args.tree_labels.blank?

        classification_tree_labels = DataCycleCore::ClassificationTreeLabel.where(name: args.tree_labels.split('|').map(&:strip))

        abort('tree_labels not found!') if classification_tree_labels.blank?

        classification_tree_labels.each(&:sort_classifications_alphabetically!)
      end
    end

    namespace :merge do
      desc 'create distinct classification tree with mappings'
      task :create_distinct_tree, [:from_tree_label, :to_tree_label] => [:environment] do |_, args|
        from_tree_label_name = args.from_tree_label.strip
        to_tree_label_name = args.to_tree_label.strip

        abort('missing from_tree_label!') if from_tree_label_name.blank?
        abort('missing to_tree_label!') if to_tree_label_name.blank?

        from_tree_label = DataCycleCore::ClassificationTreeLabel.find_by!(name: from_tree_label_name)
        to_tree_label = DataCycleCore::ClassificationTreeLabel.find_or_create_by(name: to_tree_label_name) do |tree_label|
          tree_label.seen_at = Time.zone.now
          tree_label.visibility = DataCycleCore.default_classification_visibilities
        end

        classifications = from_tree_label
          .classification_aliases
          .preload(:classification_alias_path, :primary_classification)
          .group_by { |ca| ca.classification_alias_path&.full_path_names&.reverse&.drop(1) }
          .map do |k, v|
            {
              name: k.last,
              name_i18n: v.pluck(:name_i18n).compact_blank.reduce(&:merge),
              full_path_names: k.reverse + [to_tree_label_name],
              classification_ids: v.flat_map(&:primary_classification).pluck(:id).uniq
            }
          end

        puts "upserting #{classifications.size} classifications to new tree_label"

        tmp = Time.zone.now

        to_tree_label.insert_all_classifications_by_path(classifications)

        puts "[DONE] finished upserting in #{Time.zone.now - tmp}s."
      end
    end
  end
end
