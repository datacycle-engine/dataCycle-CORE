module DataCycleCore
  class CreativeWork < ApplicationRecord
    extend ActsAsTree::TreeView
    extend ActsAsTree::TreeWalker

    # handle translations with gem Globalize
    translates :content, :properties

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # associations
    has_many :classification_creative_works
    has_many :classifications, through: :classification_creative_works
    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups
    has_many :display_classification_aliases, -> { where("classification_aliases.internal = ?", false) }, through: :classification_groups, source: :classification_alias

    belongs_to :primaryImage, class_name: 'Place', primary_key: 'id', foreign_key: 'photo'
    has_many :creative_work_places
    has_many :places, through: :creative_work_places

    acts_as_tree order: "position", foreign_key: "isPartOf"

    # custom setter
    include DataSetter

    attr_accessor :datahash

    # get data as specified in the data template
    # data hash with keys named as in schema.org
    def get_data_hash
      if translated_locales.include?(I18n.locale) || changes.count > 0 # for new data-sets with pending data in it
        data_type = metadata['validation']
        data_hash = {}
        data_type['properties'].each do |key,value|
          data_hash[key] = storage_cases_get(key,data_type['properties'][key])
        end
        data_hash
      else
        return nil
      end
    end

    # set data as specified in the data template
    # data hash with keys named as in schema.org
    def set_data_hash(data_hash)
      template_hash = metadata['validation']
      if validate?(data_hash)
        ActiveRecord::Base.transaction do
          set_template_data_hash(template_hash['properties'], data_hash)
        end
      end
      validate(data_hash) # return error/warnings from validation
    end

    def validate(data)
      template_hash = metadata["validation"]
      validator = DataCycleCore::MasterData::ValidateData.new
      validator.validate(data, template_hash)
    end

    def validate?(data, strict = false)
      template_hash = metadata['validation']
      validator = DataCycleCore::MasterData::ValidateData.new
      validator.valid?(data, template_hash, strict)
    end

    # validates given data-hash (key names as specified in the template)
    # and returns true/false
    def validate_hash?(data = collect_data, strict = false)
      template_hash = metadata['validation']
      validator = DataCycleCore::MasterData::ValidateData.new
      validator.valid_hash?(data, template_hash, strict)
    end

    # validates given data_hash (key names as specified in the template)
    # returns error-hash including all errors/warnings
    def validate_hash(data = collect_data)
      template_hash = metadata["validation"]
      validator = DataCycleCore::MasterData::ValidateData.new
      validator.validate_hash(data, template_hash)
    end

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def tags
      DataCycleCore::ClassificationAlias.
        joins(classifications: [:creative_works]).
        where("creative_works.id = ?", self.id).
        where("classification_creative_works.tag = ?", true)
    end

    # was replaced by QueryBuilders
    def search(search)
      where("headline LIKE ? OR description LIKE ?", "%#{search}%", "%#{search}%")
    end

    private

    def get_relation_ids(storage_location, tree_label)
      DataCycleCore::ClassificationCreativeWork.
        where(creative_work_id: id).
        joins(classification: [classification_groups: [classification_alias: [classification_trees: [:classification_tree_label]]]]).
        where("classification_tree_labels.name = ?", tree_label).
        pluck(:classification_id)
    end

    def set_relation_ids(storage_location, ids, tree_label)
      # insert missing ids
      return if ids.nil?
      ids.each do |location_id|
        DataCycleCore::ClassificationCreativeWork.
          find_or_create_by(
            creative_work_id: self.id,
            classification_id: location_id
          )
      end
      # delete missing ids
      found_ids = get_relation_ids(storage_location, tree_label)
      to_delete = found_ids - ids
      if to_delete.size > 0
        ap DataCycleCore::ClassificationCreativeWork.
          where(
            creative_work_id: self.id,
            classification_id: to_delete
          ).destroy_all
      end
    end

    def set_template_data_hash(properties, data_hash)
      properties.each do |key,value|
        storage_cases_set(key, data_hash[key], properties[key])
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
      #puts " key ----> #{key} | value: #{value} | #{properties}"
      case properties['storage_location']
      when 'column'
        self.method("#{key}=").call(value)
      when 'content'
        save_to_jsonb(key, value, properties, 'content')
      when 'metadata'
        save_to_jsonb(key, value, properties, 'metadata')
      when 'properties'
        save_to_jsonb(key, value, properties, 'properties')
      when 'classification_creative_works'
        set_relation_ids(properties['storage_location'], value, properties['type_name'])
      end
    end

    def save_to_jsonb(key, data, properties, location)
      # parse tree in json, to only set data specified in the data definitions
      if data.is_a?(::Hash)
        data = set_data_tree_hash(data, properties['properties'])
      end
      # set to json field (could be empty)
      if self.method("#{location}").call.blank?
        self.method("#{location}=").call({ key => data })
      else
        self.method("#{location}").call.method("[]=").call(key,data)
      end
    end

    def set_data_tree_hash(data, data_definitions)
      data_hash = {}
      return if data.blank?
      data_definitions.each do |key,value|
        unless data_definitions[key]['type'] == 'object'
          data_hash[key] = data[key]
        else
          data_hash[key] = set_data_tree_hash(data[key], data_definitions[key]['properties'])
        end
      end
      data_hash
    end

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
