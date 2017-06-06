json.classification_aliases @classification_aliases do |item|
  json.set! "name", item.sub_classification_alias.name
  json.set! "parent_classification_alias_id", item.parent_classification_alias_id
  json.set! "classification_alias_id", item.classification_alias_id
  json.set! "tree_label", item.classification_tree_label.name
end

json.set! "links", {
  first: "#{api_v1_classification_index_url}.json?page=#{1.to_s}&per=#{params[:per] || @per}",
  prev: @classification_aliases.first_page? ? nil : "#{api_v1_classification_index_url}.json?page=#{@classification_aliases.prev_page.to_s}&per=#{params[:per] || @per}",
  next: @classification_aliases.last_page?  ? nil : "#{api_v1_classification_index_url}.json?page=#{@classification_aliases.next_page.to_s}&per=#{params[:per] || @per}",
  last: "#{api_v1_classification_index_url}.json?page=#{@classification_aliases.total_pages.to_s}&per=#{params[:per] || @per}"
}.compact
