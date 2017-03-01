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

    acts_as_tree order: "position", foreign_key: "isPartOf"

    # custom setter
    include DataSetter

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def save_template (template_hash)
      return self if template_hash.empty?
      # save root node
      node_id = save_data_with_translations(self, template_hash[:data])
      # start recursive walk
    end

    private

    # perform depth-first walk
    def walk_template_tree (template_hash, parent_id)
    end

    def save_data_with_translations (node, input_hash)
      data_hash = input_hash.except(:translations)
      if input_hash.has_key?(:translations)
        input_hash[:translations].each do |language, translated_data|
          I18n.with_locale(language) do
            save_data_hash = data_hash.merge(translated_data).merge({seen_at: Time.zone.now})
            node.set_data(save_data_hash).save
          end
        end
      else
        node.set_data(data_hash).save
      end
      return node.id
    end

    def destroy_translations
      self.translations.delete_all
    end

  end
end
