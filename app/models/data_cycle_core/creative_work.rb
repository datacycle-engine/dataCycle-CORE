module DataCycleCore
  class CreativeWork < ApplicationRecord
    extend ActsAsTree::TreeView
    extend ActsAsTree::TreeWalker

    # handle translations with gem Globalize
    translates :content, :properties

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # associations
    belongs_to :primaryImage, class_name: 'Place', primary_key: 'id', foreign_key: 'photo'
    has_many :classification_creative_works
    has_many :classification_aliases, through: :classification_creative_works

    acts_as_tree order: "position", foreign_key: "isPartOf"

    # custom setter
    include DataSetter

    # get data as specified in the data template
    # data hash with keys named as in schema.org
    def get_data_type_schema
      data_type = metadata['validation']
      data_hash = {}
      data_type['properties'].each do |key,value|
        data_hash[key] = storage_cases_get(key,data_type['properties'][key])
      end
      data_hash
    end

    # get data as specified in the data template
    # data hash with key names as specified in the template
    def get_data_type
      data_type = metadata['validation']
      data_hash = collect_template_data(data_type['properties'])
    end

    def set_data_type(data_hash)
      template_hash = metadata['validation']
      unless validate?(data_hash)
        return validate(data_hash)
      end
      ActiveRecord::Base.transaction do
        set_template_data(template_hash['properties'], data_hash)
      end
    end

    # validates given data-hash (key names as specified in the template)
    # and returns true/false
    def validate?(data = collect_data, strict = false)
      template_hash = metadata['validation']
      DataCycleCore::MasterData::ValidateData.new.valid?(data, template_hash, strict)
    end

    # validates given data_hash (key names as specified in the template)
    # returns error-hash including all errors/warnings
    def validate(data = collect_data)
      template_hash = metadata["validation"]
      DataCycleCore::MasterData::ValidateData.new.validate(data, template_hash)
    end

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def self.search(search)
      where("headline LIKE ? OR description LIKE ?", "%#{search}%", "%#{search}%")
    end

    private

    def get_relation_ids(storage_location, tree_label)
      DataCycleCore::ClassificationCreativeWork.
        where(creative_work_id: id).
        joins(classification_alias: [classification_trees: [:classification_tree_label]]).
        where("classification_tree_labels.name = ?", tree_label).
        pluck(:classification_alias_id)
    end

    def set_relation_ids(storage_location, ids, tree_label)
      # insert missing ids
      ids.each do |location_id|
        DataCycleCore::ClassificationCreativeWork.
          find_or_create_by(
            creative_work_id: self.id,
            classification_alias_id: location_id
          )
      end
      # delete missing ids 
      found_ids = get_relation_ids(storage_location, tree_label)
      to_delete = found_ids - ids
      if to_delete.size > 0
        ap DataCycleCore::ClassificationCreativeWork.
          where(
            creative_work_id: self.id,
            classification_alias_id: to_delete
          ).destroy_all
      end
    end

    def collect_template_data(properties)
      data_hash = {}
      properties.each do |key,value|
        key_label = properties[key]['label']
        if properties[key]['type'] == 'object'
          data_hash[key_label] = walk_data_tree(properties[key]['properties'], self.method(properties[key]['storage_location']).call[key])
          next
        end
        data_hash[key_label] = storage_cases_get(key, properties[key])
      end
      data_hash
    end

    def set_template_data(properties, data_hash)
      puts "set_template_data"
      properties.each do |key,value|
        key_label = properties[key]['label']
        if properties[key]['type'] == 'object'
          build_hash = set_data_tree(properties[key]['properties'], data_hash[key_label])
          self.method(properties[key]['storage_location']).call[key] = build_hash
          next
        end
        storage_cases_set(key, data_hash[key_label], properties[key])
      end
    end

    def storage_cases_get(key, properties)
      case properties["storage_location"]
      when "column"
        self.method(key).call
      when "content"
        self.content[key]
      when "metadata"
        self.metadata[key]
      when "properties"
        self.properties[key]
      when "classification_creative_works"
        get_relation_ids(properties["storage_location"], properties["type_name"])
      end
    end

    def storage_cases_set(key, value, properties)
      puts " key ----> #{key} | value: #{value} | #{properties}"
      case properties['storage_location']
      when 'column'
        self.method("#{key}=").call(value)
      when 'content'
        if self.content.blank?
          self.content = { key => value }
        else
          self.content[key] = value
        end
      when 'metadata'
        if self.metadata.blank?
          self.metadata = { key => value }
        else
          self.metadata[key] = value
        end
      when 'properties'
        if self.properties.blank?
          self.properties = { key => value }
        else
          self.properties[key] = value
        end
      when 'classification_creative_works'
        set_relation_ids(properties['storage_location'], value, properties['type_name'])
      end
    end

    def walk_data_tree(data_definitions, data)
      data_hash = {}
      data_definitions.each do |key,value|
        key_label = data_definitions[key]['label']
        unless data_definitions[key]['type'] == 'object'
          data_hash[key_label] = data[key]
        else
          data_hash[key_label] = walk_data_tree(data_definitions[key]['properties'],data[key])
        end
      end
      data_hash
    end

    def set_data_tree(data_definitions, data)
      data_hash = {}
      data_definitions.each do |key,value|
        key_label = data_definitions[key]['label']
        unless data_definitions[key]['type'] == 'object'
          data_hash[key] = data[key_label]
        else
          data_hash[key] = set_data_tree(data_definitions[key]['properties'],data[key_label])
        end
      end
      data_hash
    end

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
