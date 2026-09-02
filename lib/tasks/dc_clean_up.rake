# frozen_string_literal: true

require 'rake_helpers/shell_helper'
require 'rake_helpers/cleanup_helper'

namespace :dc do
  namespace :clean_up do
    desc 'Remove all data from external_source'
    task :external_source_data, [:external_source_id, :dry_run] => [:environment] do |_, args|
      dry_run = args.fetch(:dry_run, false)
      external_source = DataCycleCore::ExternalSystem.find(args.fetch(:external_source_id))

      if external_source.nil?
        puts 'Error: No ExternalSystem found!'
        exit(-1)
      end

      external_contents = DataCycleCore::Thing.includes(:content_content_b).where(external_source_id: external_source.id).with_content_type('entity')
      initial_external_contents_count = external_contents.size
      puts "Found #{initial_external_contents_count} items"

      has_no_relation = DataCycleCore::Thing
        .includes(:content_content_b)
        .where(
          external_source_id: external_source.id,
          content_contents: {
            id: nil
          }
        ).with_content_type('entity')

      items_to_delete = has_no_relation.count
      puts "Items without relation : #{external_source.name} (#{items_to_delete}) - (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

      if dry_run
        puts 'Dry run: no database changes made'
        exit(-1)
      end

      progressbar = ProgressBar.create(total: items_to_delete, title: 'Deleting')

      has_no_relation.find_each do |data_item|
        data_item.destroy_content
        progressbar.increment
      end
      progressbar.finish

      if items_to_delete.positive? && initial_external_contents_count != external_contents.size
        Rake::Task['dc:clean_up:external_source_data'].reenable
        Rake::Task['dc:clean_up:external_source_data'].invoke(external_source.id)
      end

      # find classifications for extenal_source
      tree_label = DataCycleCore::ClassificationTreeLabel.where(external_source_id: external_source.id)
      puts "Found ClassificationTreeLabels: #{tree_label.count}"
      tree_label.each do |classification_tree_label|
        if classification_tree_label.things.any?
          puts "Found ClassificationTreeLabel with linked content: #{classification_tree_label.id}"
        else
          classification_tree_label.destroy
        end
      end
    end

    desc 'Check all external_sources for orphaned data (does not modify the data)'
    task external_data_check: :environment do
      puts "checking ExternalSystems (#{DataCycleCore::ExternalSystem.count}) dependencies:"
      linked_data = DataCycleCore::ExternalSystem.all.filter_map do |item|
        name = CleanupHelper.identify_external_source(item)
        next if name.blank?

        linked = CleanupHelper.linked(name)
        next if linked.blank?

        { external_source_id: item.id, name: item.name, linked: }
      end

      dirty_data = []

      linked_data.each do |external_source|
        puts "\n#{external_source[:name]}"
        puts '-' * 70
        external_source[:linked].pluck(:template).uniq.each do |dependency|
          all_items = DataCycleCore::Thing.where(
            external_source_id: external_source[:external_source_id],
            template_name: dependency
          ).count
          orphaned_items = DataCycleCore::Thing.left_outer_joins(:content_content_b).where(
            things: {
              external_source_id: external_source[:external_source_id],
              template_name: dependency
            },
            content_contents: {
              content_b_id: nil
            }
          ).pluck(:id)

          recheck = DataCycleCore::ContentContent.where(content_a_id: orphaned_items).or(DataCycleCore::ContentContent.where(content_b_id: orphaned_items)).count
          puts "ERROR: recheck has found  --> #{recheck} <-- orphans still linked to content!!" if recheck.positive?

          dirty_data.push({ name: external_source[:name], id: external_source[:external_source_id], template: dependency }) if orphaned_items.size.positive?
          puts "         #{dependency.ljust(15)}   |   total: #{all_items.to_s.rjust(6)}   |   orphaned: #{orphaned_items.size.to_s.rjust(6)}"
        end
        puts '-' * 70
      end

      if dirty_data.size.positive?
        puts "\nSuggested cleanup Tasks:"
        dirty_data.each do |task|
          puts "#{task[:name].ljust(35)} bundle exec rails #{ENV['CORE_RAKE_PREFIX']}dc:clean_up:external_data#{'\\' if ShellHelper.zsh?}[#{task[:id]},\"#{task[:template].tr(' ', '\\ ')}\"#{'\\' if ShellHelper.zsh?}]"
        end
      else
        puts AmazingPrint::Colors.green("\n[✔] ... looks good 🚀")
      end
    end

    desc 'delete orphaned external_data'
    task :external_data, [:external_system_or_stored_filter_id, :templates] => [:environment] do |t, args|
      templates = args.fetch(:templates, '').split('|').filter_map do |template_name|
        DataCycleCore::ThingTemplate.find_by(template_name: template_name)&.template_name
      end

      external_source_or_collection_id = args.external_system_or_stored_filter_id

      collection = DataCycleCore::Collection.find_by(id: external_source_or_collection_id)
      external_system = DataCycleCore::ExternalSystem.find_by(id: external_source_or_collection_id)

      abort('Please provide an array of templates seperated like that template_name|template_name !') if templates.blank?
      abort('Please provide an external_source_id or a collection_id') if collection.blank? && external_system.blank?

      logger = Logger.new('log/deletes_orphans.log')

      things =
        if external_system.present?
          DataCycleCore::Thing.where(external_source_id: external_system.id)
        else
          collection.things
        end

      orphans = things
        .where(template_name: templates)
        .where.missing(:content_content_b)

      origin = external_system.present? ? external_system.name : "#{collection.type || 'Collection'}: #{collection.id}"

      items_to_delete = orphans.count
      logger.info("[#{t.name}] Started deleting #{items_to_delete} orphans with these templates #{templates} from #{origin}")

      progressbar = ProgressBar.create(total: items_to_delete, title: templates.join('/'))

      deleted = 0
      orphans.find_in_batches(batch_size: 1000) do |batch|
        # WorkerPool#wait! shuts down the underlying thread pool, so a fresh pool
        # is required per batch (reusing one raises Concurrent::RejectedExecutionError).
        queue = DataCycleCore::WorkerPool.new

        batch.each do |orphan|
          queue.append do
            # Concurrent deletes of heavily shared content (e.g. "Bild") can deadlock
            # on overlapping row/index locks; retry the rolled-back transaction.
            CleanupHelper.with_deadlock_retry(logger:, identifier: "Thing #{orphan.id}") do
              orphan.destroy_content(destroy_linked: true)
            end
            progressbar.increment
          end
        end

        queue.wait!
        deleted += batch.size
      end

      logger.info("[#{t.name}] [DONE] Deleted #{deleted}/#{items_to_delete} orphans (templates: #{templates}) from #{origin}")
      progressbar.finish
    end

    desc 'archive orphaned imported content of a stored filter instead of deleting it'
    task :archive_orphans, [:stored_filter_id_or_slug, :templates, :min_age_days, :dry_run, :life_cycle_stage] => [:environment] do |t, args|
      templates = args.fetch(:templates, '').to_s.split('|').filter_map do |template_name|
        DataCycleCore::ThingTemplate.find_by(template_name: template_name.squish)&.template_name
      end

      # the same guard the sibling delete task uses: without templates a mistyped filter would act
      # on everything it happens to match
      abort('Please provide an array of templates seperated like that template_name|template_name !') if templates.blank?

      collection = DataCycleCore::Collection.by_id_name_slug(args.stored_filter_id_or_slug.to_s).first
      abort("Collection #{args.stored_filter_id_or_slug} does not exist!") if collection.blank?

      min_age_days = args.fetch(:min_age_days, 3).to_i
      dry_run = args.fetch(:dry_run, false).to_s == 'true'

      collection.language = Array.wrap(I18n.available_locales).map(&:to_s)
      scope = collection.unsorted_things.where(template_name: templates)

      logger = Logger.new('log/archive_orphans.log')
      orphans = CleanupHelper.orphaned_imported(scope, min_age_days:)
      reattached = CleanupHelper.reattached(scope)

      if dry_run
        logger.info("[#{t.name}] [DRY RUN] #{orphans.count} orphans would be archived, #{reattached.count} linked contents would be checked for reactivation (collection: #{collection.id}, templates: #{templates}, min_age_days: #{min_age_days})")
        next
      end

      logger.info("[#{t.name}] Started archiving orphans (collection: #{collection.id}, templates: #{templates}, min_age_days: #{min_age_days})")

      archived = CleanupHelper.archive_contents!(orphans, logger:)
      # "feed wins": a content that is linked again belongs back in the active pool. Runs after the
      # archiving pass, which by definition cannot have touched anything that is linked.
      reactivated = CleanupHelper.reactivate_contents!(reattached, stage_name: args[:life_cycle_stage], logger:)

      logger.info("[#{t.name}] [DONE] Archived #{archived} orphans, reactivated #{reactivated} contents (templates: #{templates})")
    end

    desc 'Check all embedded for orphaned data (does not modify the data)'
    task embedded_check: :environment do
      puts 'checking embedded_data:'
      puts '-' * 70

      orphaned_data = []
      CleanupHelper.embedded.each do |key, value|
        orphans = CleanupHelper.orphaned_embedded(value.uniq, key)
        total = DataCycleCore::Thing.where(template_name: key).count
        puts "#{key.ljust(25)}  |   total: #{total.to_s.rjust(6)}   |   orphaned: #{orphans.size.to_s.rjust(6)}"
        orphaned_data.push(key) if orphans.size.positive?
      end
      puts '-' * 70

      if orphaned_data.size.positive?
        puts "\nSuggested cleanup Tasks:"
        orphaned_data.each do |embedded|
          puts "#{embedded.to_s.ljust(25)} bundle exec rails #{ENV['CORE_RAKE_PREFIX']}dc:clean_up:embedded#{'\\' if ShellHelper.zsh?}[\"#{embedded.tr(' ', '\\ ')}\"#{'\\' if ShellHelper.zsh?}]"
        end
      else
        puts AmazingPrint::Colors.green("\n[✔] ... looks good 🚀")
      end
    end

    desc 'delete orphaned embedded'
    task :embedded, [:embedded] => [:environment] do |_, args|
      embedded_template = args.fetch(:embedded)
      template = DataCycleCore::Thing.find_by(template_name: embedded_template)
      ShellHelper.error("Error: No embedded template found for #{embedded_template}") if template.blank?
      ShellHelper.error("Error: #{embedded_template} is not an embedded template!") unless template.schema['content_type'] == 'embedded'

      main_templates = embedded[embedded_template]
      orphans = CleanupHelper.orphaned_embedded(main_templates, embedded_template)
      items_to_delete = orphans.count
      puts "#{"embedded: #{embedded_template}".ljust(25)} used in:  #{main_templates.map(&:to_s)}"

      progressbar = ProgressBar.create(total: items_to_delete, title: 'Deleting')
      orphans.each do |orphan|
        orphan.destroy_content(save_history: false)
        progressbar.increment
      end
      progressbar.finish
    end

    desc 'find_orphaned_things in mongodb'
    task :find_orphaned_things_in_mongodb, [:template_name, :external_system_id, :collection_name] => [:environment] do |_, args|
      collection_name = args.fetch(:collection_name, false)
      external_system_id = args.fetch(:external_system_id, false)
      template_name = args.fetch(:template_name, false)

      ShellHelper.error 'invalid number of arguments' unless collection_name.present? && external_system_id.present? && template_name.present?

      external_system = DataCycleCore::ExternalSystem.find(external_system_id)
      things = DataCycleCore::Thing.where(template_name:, external_source_id: external_system.id)

      puts "things (#{template_name}) found: #{things.size}\n"

      things_missing = 0
      things_missing_keys = []

      external_system.collection(collection_name) do |collection|
        things.each do |thing|
          next unless collection.find({ external_id: thing.external_key }).none?

          # puts "item with external key: #{thing.external_key} not found in mongo collection\n"
          things_missing += 1
          things_missing_keys << thing
          next
        end
      end
      puts "things (#{template_name}) missing in mongoDB: #{things_missing}\n"
    end

    desc 'Build a stored filter per template (system excludes and/or base stored filters) and delete its orphans (see #42950)'
    task orphans_by_template: :environment do
      config = DataCycleCore.cleanup_orphans.presence
      abort("No config found: #{config}") if config.blank?

      logger = Logger.new('log/delete_orphans_by_template.log')

      config.each do |template, entry|
        unless DataCycleCore::ThingTemplate.exists?(template_name: template)
          logger.info("[SKIP] Template '#{template}' does not exist – skipping.")
          next
        end

        unless entry.is_a?(Hash)
          logger.error("[SKIP] '#{template}': config must be a hash with 'exclude' and/or 'stored_filters' (got #{entry.class}).")
          next
        end

        has_exclude = entry.key?('exclude')
        has_base = entry['stored_filters'].present?

        unless has_exclude || has_base
          logger.error("[SKIP] '#{template}': neither 'exclude' nor 'stored_filters' configured – skipping.")
          next
        end

        # excludes mode: resolve external-system identifiers -> ids (empty list = clean in ALL systems)
        exclude_source_ids = nil
        if has_exclude
          identifiers = Array(entry['exclude'])
          systems = DataCycleCore::ExternalSystem.where(identifier: identifiers)
          exclude_source_ids = systems.pluck(:id)
          missing = identifiers - systems.pluck(:identifier)
          logger.warn("[WARN] '#{template}': unknown external-system identifiers (ignored): #{missing.join(', ')}") if missing.any?
        end

        # base-filters mode: resolve stored-filter ids; skip the template entirely if none exist, so the
        # generated filter never collapses to "whole template" (filter_ids([]) is a no-op) and mass-deletes.
        base_filter_ids = nil
        if has_base
          requested = Array(entry['stored_filters']).map(&:to_s)
          base_filter_ids = DataCycleCore::StoredFilter.where(id: requested).pluck(:id)
          missing = requested - base_filter_ids.map(&:to_s)
          logger.warn("[WARN] '#{template}': unknown stored_filters (ignored): #{missing.join(', ')}") if missing.any?

          if base_filter_ids.blank?
            logger.error("[SKIP] '#{template}': none of the configured stored_filters exist (#{requested.join(', ')}) – skipping to avoid deleting the whole template.")
            next
          end
        end

        filter = DataCycleCore::StoredFilter.find_or_create_by(name: "Cleanup Waisen – #{template}")
        filter.api = true
        filter.parameters = CleanupHelper.orphan_filter_parameters(template_name: template, exclude_source_ids:, base_filter_ids:)
        filter.save!

        logger.info("[INFO] '#{template}': stored filter #{filter.id} (excluded systems: #{exclude_source_ids&.size || 0}, base filters: #{base_filter_ids&.size || 0})")

        Rake::Task['dc:clean_up:external_data'].reenable
        Rake::Task['dc:clean_up:external_data'].invoke(filter.id, template)
      end
    end
  end
end
