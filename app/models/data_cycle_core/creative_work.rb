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
    has_many :classifications_creative_works
    has_many :classification_aliases, through: :classifications_creative_works

    acts_as_tree order: "position", foreign_key: "isPartOf"

    # custom setter
    include DataSetter

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def self.save_template (template_hash)
      walk_template_tree(template_hash, nil)
    end

    def load_template
      walk_load_tree(self)
    end

    def self.validate? (template_hash)
      # check if validation is present
      validate_status = false
      template_hash.deep_symbolize_keys!
      unless template_hash.empty?
        if template_hash.has_key?(:data)
          if template_hash[:data].has_key?(:metadata)
            if template_hash[:data][:metadata].has_key?(:data_cycle)
              if template_hash[:data][:metadata][:data_cycle].has_key?(:validation)
                validate_status = JSON::Validator.validate(
                  template_hash[:data][:metadata][:data_cycle][:validation],
                  template_hash
                )
              end
            end
          end
        end
      end
      return validate_status
    end

    private

    def self.walk_template_tree(template_hash, parent)
      return nil if template_hash.empty?
      if parent.nil?
        parent_id = nil
      else
        parent_id = parent.id
      end
      node_object = save_data_with_translations(CreativeWork.new, template_hash[:data], parent_id)
      if template_hash.has_key?(:nodes)
        template_hash[:nodes].each do |node|
          walk_template_tree(node, node_object)
        end
      end
      return node_object
    end

    def self.save_data_with_translations(node, input_hash, parent_id)
      data_hash = input_hash.except(:translations)
      if input_hash.has_key?(:translations)
        input_hash[:translations].each do |language, translated_data|
          I18n.with_locale(language) do
            save_data_hash = data_hash.merge(translated_data).merge({seen_at: Time.zone.now, isPartOf: parent_id})
            node.set_data(save_data_hash).save
          end
        end
      else
        node.set_data(data_hash.merge({isPartOf: parent_id})).save
      end
      return node
    end

    def walk_load_tree(node)
      node_hash = load_data_with_translations(node)
      children_hash = []
      CreativeWork.where(isPartOf: node.id).order(position: :asc).each do |child_node|
        child_hash = walk_load_tree(child_node)
        children_hash.push(child_hash)
      end
      if children_hash.count == 0
        hash = node_hash
      else
        hash = node_hash.deep_merge({nodes: children_hash})
      end
      return hash
    end

    def load_data_with_translations(node)
      language_hash = {}
      node.translations.each do |language|
        language_name = language.locale.to_sym
        language_hash.deep_merge!({
          language_name => {
            content: language.content,
            properties: language.properties
          }
        })
      end
      return {
        data: {
          headline: node.headline,
          description: node.description,
          position: node.position,
          metadata: node.metadata,
          isPartOf: node.isPartOf,
          translations: language_hash
        }
      }

    end

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
