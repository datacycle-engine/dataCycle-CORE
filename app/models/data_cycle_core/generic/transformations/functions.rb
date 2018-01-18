module DataCycleCore::Generic::Transformations::Functions
  extend Transproc::Registry
  import Transproc::HashTransformations
  import Transproc::Conditional
  import Transproc::Recursion

  def self.underscore_keys(data_hash)
    Hash[data_hash.to_a.map { |k, v| [k.to_s.underscore, v.is_a?(Hash) ? underscore_keys(v) : v] }]
  end

  def self.strip_all(data_hash)
    Hash[data_hash.to_a.map { |k, v| [k, v.is_a?(Hash) ? strip_all(v) : (v.is_a?(String) ? v.strip : v)] }]
  end

  def self.location(data_hash)
    location = RGeo::Geographic.spherical_factory(srid: 4326).point(data_hash['longitude'].to_f, data_hash['latitude'].to_f) unless data_hash['longitude'].blank? || data_hash['latitude'].blank?
    location ||= nil
    data_hash.nil? ? { 'location' => location } : data_hash.merge({ 'location' => location })
  end

  def self.compact(data_hash)
    data_hash.compact
  end

  def self.merge(data_hash, new_hash)
    data_hash.merge(new_hash)
  end

  def self.tags_to_ids(data_hash, attribute, tree_label)
    if data_hash[attribute].blank?
      data_hash[attribute] = []
    else
      data_hash[attribute] = data_hash[attribute].map do |keyword|
        DataCycleCore::Classification
          .joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]])
          .where("classification_tree_labels.name = ? and classifications.name = ? ", tree_label, keyword).try(:first).try(:id)
      end || []
    end
    data_hash
  end

  def self.add_field(data_hash, name, function)
    data_hash.merge({ name => function.call(data_hash) })
  end
end
