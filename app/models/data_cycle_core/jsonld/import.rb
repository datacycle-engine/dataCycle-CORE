module DataCycleCore
  module Jsonld

    class Import

      def initialize ( uuid , incremental_update = false, page_size = 300, verbose = false )
        @external_source_id = uuid
        @download_page_size = page_size
        @verbose = verbose
        @incremental_update = incremental_update
        @log = DataCycleCore::Logger.new('jsonld_import')
        init_db
      end

      def init_db
        save_logger_level = Rails.logger.level
        Rails.logger.level = 4 unless @verbose

        @classifications_tree_label_id = init_or_create_classifications_trees_label('imported')

        Rails.logger.level = save_logger_level
      end

      def init_or_create_classifications_trees_label(label)
        classifications_trees_label = ClassificationTreeLabel.find_or_initialize_by(name: label, external_source_id: @external_source_id)
        classifications_trees_label.seen_at = Time.zone.now
        classifications_trees_label.save
        classifications_trees_label.id
      end

      def check_for_classification_keyword(keyword)
        classification = Classification.first_or_initialize(name: keyword, external_source_id: @external_source_id, external_type: "keyword") do |data_set|
          data_set.seen_at = Time.zone.now
        end
        classification.save
        # check if entries up to tree with label 'import' exists
        class_group = ClassificationGroup.
          joins(classification_alias: [classification_trees: [:classification_tree_label]]).
          where("classification_groups.classification_id = ?", classification.id).
          where("classification_tree_labels.name = ?", 'imported')
        if class_group.count < 1
          classification_alias = ClassificationAlias.first_or_initialize(name: keyword) do |data_set|
            data_set.seen_at = Time.zone.now
          end
          classification_alias.save
          ClassificationGroup.
            first_or_initialize(
              classification_id: classification.id,
              classification_alias_id: classification_alias.id,
              external_source_id: @external_source_id
            ) do |data_set|
              data_set.seen_at = Time.zone.now
          end
          ClassificationTree.
            first_or_initialize(
              classification_alias_id: classification_alias.id,
              external_source_id: @external_source_id,
              classification_tree_label_id: @classifications_tree_label_id,
              parent_classification_alias_id: nil
            ) do |data_set|
              data_set.seen_at = Time.zone.now
          end
        end
      end

    # main import functionality
      def import
        Mongoid.override_database(nil) #reset to default
        Mongoid.override_database("#{DownloadCreativeWork.database_name}_#{@external_source_id}")

        import_logging do
          import_creative_work
        end

        Mongoid.override_database(nil) #reset to default
      end

    private

      def import_creative_work
        data_template = CreativeWork.
          where(template: true, headline: "Bild", description: "ImageObject").
          first
        validation = data_template.metadata['validation']
        i = 0
        page_size = 1#50 #avoid timeout from Mongo-cursor!!!
        total_items=DownloadCreativeWork.count
        #pages = total_items.fdiv(page_size).ceil
        pages = 3
        pages.times do |index|
          DownloadCreativeWork.all.extras(:limit => page_size, :skip => (index*page_size)).each do |data_set|
            ActiveRecord::Base.transaction do

              to_update_image = CreativeWork
                .where(
                  "metadata ->> 'external_key' = ? AND external_source_id = ?",
                  data_set.id,
                  @external_source_id
                ).first_or_initialize
              if to_update_image.metadata.nil?
                to_update_image.metadata = { "validation" => validation }
              else
                to_update_image.metadata['validation'] = validation
              end
              to_update_image.metadata['external_key'] = data_set.id

              data_set.dump.each do |lang, data_hash|
                puts "#{i.to_s.ljust(5)} | #{data_set.id.ljust(51)}| #{Time.zone.now}" if (i % 50) == 0
                i += 1
                data = data_hash.except("@context", "@type", "visibility", "keywords")
                I18n.with_locale(lang) do
                  errors = to_update_image.set_data_hash(data)
                end
              end
              to_update_image.save

              # read data for relations (keywords,places)
              #create relation for keywords
              puts "keywords = #{data_set.dump.each.first[1]['keywords']}"
              keywords = data_set.dump.each.first[1]['keywords']
              unless keywords.nil?
                keywords.each do |keyword|
                  classification_id = check_for_classification_keyword(keyword)
                  updated_ccw = ClassificationCreativeWork
                    .find_or_create_by(
                      creative_work_id: to_update_image.id,
                      classification_id: classification_id,
                      tag: true
                    )
                  updated_ccw.seen_at = Time.zone.now
                  updated_ccw.save
                end
              end
              # insert place if needed

            end
          end
        end
      end

    # logging ceremony for import logic
      def import_logging
        start_time = Time.zone.now
        @log.info "BEGIN IMPORT : " + start_time.to_s
        @log.info 'JSON-LD Importer:'
        @log.info "MongoDB: #{DownloadCreativeWork.database_name}"

        save_logger_level = Rails.logger.level
        Rails.logger.level = 4 unless @verbose

        yield

        end_time = Time.zone.now
        @log.info "  total import time: #{(end_time-start_time).round(2)} [s]"
        @log.info 'end'
        @log.info "END IMPORT : " + end_time.to_s

        Rails.logger.level = save_logger_level
      end
    end
  end
end
