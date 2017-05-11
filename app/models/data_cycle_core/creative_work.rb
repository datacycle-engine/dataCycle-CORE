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
    def get_data_schema
      data_type = metadata["validation"]
      data_hash = {}
      data_type["properties"].each do |key,value|
        data_hash[key] = storage_cases(key,data_type["properties"][key])
      end
      data_hash
    end

    # get data as specified in the data template
    # data hash with key names as specified in the template
    def get_data
      data_type = metadata["validation"]
      data_hash = collect_template_data(data_type["properties"])
    end

    # validates given data-hash (key names as specified in the template)
    # and returns true/false
    def validate?(data = collect_data, strict = false)
      template_hash = metadata["validation"]
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

    def collect_template_data(properties)
      data_hash = {}
      properties.each do |key,value|
        key_label = properties[key]["label"]
        if properties[key]["type"] == "object"
          data_hash[key_label] = walk_data_tree(properties[key]["properties"], self.method(properties[key]["storage_location"]).call[key])
          next
        end
        data_hash[key_label] = storage_cases(key, properties[key])
      end
      data_hash
    end

    def storage_cases(key, properties)
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

    def walk_data_tree(data_definitions, data)
      data_hash = {}
      data_definitions.each do |key,value|
        key_label = data_definitions[key]["label"]
        unless data_definitions[key]["type"] == "object"
          data_hash[key_label] = data[key]
        else
          data_hash[key_label] = walk_data_tree(data_definitions[key]["properties"],data[key])
        end
      end
      data_hash
    end

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
