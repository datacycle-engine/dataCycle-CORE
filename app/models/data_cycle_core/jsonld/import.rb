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
        external_source = ExternalSource.where(id: @external_source_id).first

        if ClassificationsTreesLabel.where(name: 'imported', external_source_id: @external_source_id).count < 1
          ClassificationsTreesLabel
            .new(name: 'imported', seen_at: Time.zone.now, external_source_id: @external_source_id)
            .save
        end
        @classifications_trees_label_id = ClassificationsTreesLabel
          .where(name: 'imported', external_source_id: @external_source_id)
          .first
          .id

        if ClassificationsTreesLabel.where(name: 'CreativeWork', external_source_id: @external_source_id).count < 1
          ClassificationsTreesLabel
            .new(name: 'CreativeWork', seen_at: Time.zone.now, external_source_id: @external_source_id)
            .save
        end
        tree_label_id_creative_work = ClassificationsTreesLabel
          .where(name: 'CreativeWork', external_source_id: @external_source_id)
          .first
          .id
        top_level_classifications_tree_entries = ClassificationsTree
          .where(
            external_source_id: @external_source_id,
            classifications_trees_label_id: tree_label_id_creative_work,
            parent_classifications_alias_id: nil
          )
        top_level_classifications_tree_entries.each do |item|
          if item.sub_classifications_alias.name == 'ImageObject'
            @creative_works_classification_alias_id = item.sub_classifications_alias.id
          end
        end
        if @creative_works_classification_alias_id.nil?
          classification_alias = ClassificationsAlias.new(name: 'ImageObject', seen_at: Time.zone.now)
          classification_alias.save
          @creative_works_classification_alias_id = classification_alias.id
          ClassificationsTree
            .new(
              external_source_id: @external_source_id,
              classifications_alias_id: @creative_works_classification_alias_id,
              classifications_trees_label_id: tree_label_id_creative_work,
              seen_at: Time.zone.now
            )
            .save
        end
      end

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
        DownloadCreativeWork.all.each do |data_set|
          ActiveRecord::Base.transaction do
            record = data_set.dump
            data_image = {
              'headline' => record["headline"].values.first,
              'content' => {'url' => record["image"]},
              'metadata' => {external_key: record["@id"]},
              'seen_at' => Time.zone.now,
              'position' => 0,
              'external_source_id' => @external_source_id
            }
            to_update_image = CreativeWork
              .where(
                "metadata ->> 'external_key' = ? AND external_source_id = ?",
                record['@id'],
                @external_source_id
              )
              .first_or_initialize
              .set_data(data_image)
            to_update_image.save
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
