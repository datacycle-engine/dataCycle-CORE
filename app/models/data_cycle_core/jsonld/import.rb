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
        @classifications_trees_label_id = init_or_create_classifications_trees_label('imported')
        @tree_label_id_creative_work =    init_or_create_classifications_trees_label('CreativeWork')

        @creative_works_classification_alias_id = check_for_tree_entry_with_classification_alias('ImageObject')
        if @creative_works_classification_alias_id.nil?
          @creative_works_classification_alias_id = insert_classification_alias_and_tree_entry('ImageObject', @tree_label_id_creative_work)
        end
      end

      def init_or_create_classifications_trees_label(label)
        if ClassificationsTreesLabel.where(name: label, external_source_id: @external_source_id).count < 1
          ClassificationsTreesLabel
            .new(name: label, seen_at: Time.zone.now, external_source_id: @external_source_id)
            .save
        end
        ClassificationsTreesLabel
          .where(name: label, external_source_id: @external_source_id)
          .first
          .id
      end

      def check_for_tree_entry_with_classification_alias(label)
        classification_alias_id = nil
        top_level_classifications_tree_entries = ClassificationsTree
          .where(
            external_source_id: @external_source_id,
            classifications_trees_label_id: @tree_label_id_creative_work,
            parent_classifications_alias_id: nil
          )
        top_level_classifications_tree_entries.each do |item|
          if item.sub_classifications_alias.name == label
            classification_alias_id = item.sub_classifications_alias.id
          end
        end
        classification_alias_id
      end

      def insert_classification_alias_and_tree_entry(label, tree_label)
        classification_alias = ClassificationsAlias.new(name: label, seen_at: Time.zone.now)
        classification_alias.save
        creative_works_classification_alias_id = classification_alias.id
        ClassificationsTree
          .new(
            external_source_id: @external_source_id,
            classifications_alias_id: creative_works_classification_alias_id,
            classifications_trees_label_id: tree_label,
            seen_at: Time.zone.now
          )
          .save
        creative_works_classification_alias_id
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
        DownloadCreativeWork.all.each do |data_set|
          ActiveRecord::Base.transaction do
            data_image = non_translated_attributes(data_set.dump)
            to_update_image = CreativeWork
              .where(
                "metadata ->> 'external_key' = ? AND external_source_id = ?",
                data_set.dump['@id'],
                @external_source_id
              )
              .first_or_initialize
              .set_data(data_image)
            to_update_image.content_translations = translated_attributes(data_set.dump, to_update_image.content_translations)
            to_update_image.save

            # create relation for keywords
            data_set.dump['keywords'].each do |keyword|
              classification_alias_id = check_for_tree_entry_with_classification_alias(keyword)
              if classification_alias_id.nil?
                classification_alias_id = insert_classification_alias_and_tree_entry(keyword, @tree_label_id_creative_work)
              end
              updated_ccw = ClassificationsCreativeWork
                .find_or_create_by(
                  creative_work_id: to_update_image.id,
                  classifications_alias_id: classification_alias_id,
                  tag: true
                )
              updated_ccw.seen_at = Time.zone.now
              updated_ccw.save
            end
          end
        end
      end

      def non_translated_attributes(record)
        if record["headline"].values.count > 0
          headline = record["headline"].values.first
        else
          headline = nil
        end
        { 'headline' => headline,
          'content' => {},
          'metadata' => {
            type: record["@type"],
            external_key: record["@id"],
            url: record["image"],
            fileFormat: record["fileFormat"],
            width: record["width"],
            height: record["height"],
            contentSize: record["contentSize"],
            contentLocation: record["contentLocation"],
            license: record["license"],
            identifier: record["identifier"],
            dateCreated: record["dateCreated"],
            dateModified: record["dateModified"]
          },
          'seen_at' => Time.zone.now,
          'position' => 0,
          'external_source_id' => @external_source_id
        }
      end

      def translated_attributes(record, translation_hash)
        translation_hash = {} if translation_hash.nil?
        translation_hash.deep_merge!(get_translations("headline",record)){|key,oldval,newval| newval}
        translation_hash.deep_merge!(get_translations("description",record)){|key,oldval,newval| newval}
      end

      def get_translations(attrib, record)
        trans_hash = {}
        record[attrib].each do |language, attrib_value|
          trans_hash.deep_merge!({language => {attrib => attrib_value}})
        end
        trans_hash
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
