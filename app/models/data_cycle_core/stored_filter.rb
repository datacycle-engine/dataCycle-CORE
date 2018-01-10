module DataCycleCore
  class StoredFilter < ApplicationRecord

    # example_data = {
    #   "classifications" => {
    #     "Inhaltstypen" => [
    #       "54d6f2b4-4c95-4da7-a0de-a2a2f6e59a82",
    #       "07ede09f-0e92-46f9-a239-03ada625c584",
    #       "b54f672d-4a89-42d8-b39f-39d0ace73f79",
    #       "ea9e3904-81ee-4c9c-81fb-330a700ac0e7"
    #     ],
    #     "Bundesländer" => [
    #       "9d6a682e-36d7-46a8-ad23-b0ee86cc46b1",
    #       "a177cece-7349-4c0f-b6a0-2711fc416a99"
    #     ],
    #     "Inhaltspools" => [
    #       "a9b25ff1-5af2-4f21-b61e-408812e14b0d"
    #     ]
    #   },
    #   "language" => "de",
    #   "search"=>"test"
    # }

    def apply
      language = parameters['language'] || 'de'
      if parameters.has_key?('search') # --> need ranking
        search_string = parameters['search'].split(" ").join("%")
        order_string = "boost * (
          8 * similarity(classification_string,'%#{search_string}%') +
          4 * similarity(headline, '%#{search_string}%') +
          2 * ts_rank_cd(words, plainto_tsquery('simple', '#{parameters['search'].squish}'),16) +
          1 * similarity(full_text, '%#{search_string}%'))
          DESC NULLS LAST,
          updated_at DESC"
      else
        order_string = 'boost DESC NULLS LAST, updated_at DESC'
      end

      query = DataCycleCore::Filter::Search.new(language).in_validity_period
      query = query.order(order_string)
      query = query.fulltext_search(parameters['search']) unless parameters['search'].blank?

      unless parameters['classifications'].blank?
        parameters['classifications'].each do |tree_label, class_array|
          query = query.with_classification_alias_ids(class_array)
        end
      end

      query
    end
  end
end
