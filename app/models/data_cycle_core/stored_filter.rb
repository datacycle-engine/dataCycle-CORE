module DataCycleCore
  class StoredFilter < ApplicationRecord

    scope :by_user, -> (user){ where user: user }
    belongs_to :user


    # example_data = {
    #   "order" => "boost * (
    #                 8 * similarity(classification_string,'%test%') +
    #                 4 * similarity(headline, '%test%') +
    #                 2 * ts_rank_cd(words, plainto_tsquery('simple', 'test'),16) +
    #                 1 * similarity(full_text, '%test%')
    #               ) DESC NULLS LAST,
    #               updated_at DESC",
    #   "fulltext_search" => "test",
    #   "in_validity_period" => "2018-01-11T15:33:24.517Z",
    #   "with_classification_alias_ids" => {
    #     "Inhaltspools" => ["a9b25ff1-5af2-4f21-b61e-408812e14b0d"],
    #     "Inhaltstypen" => ["54d6f2b4-4c95-4da7-a0de-a2a2f6e59a82","07ede09f-0e92-46f9-a239-03ada625c584",
    #                        "b54f672d-4a89-42d8-b39f-39d0ace73f79","ea9e3904-81ee-4c9c-81fb-330a700ac0e7"],
    #     "Bundesländer" => ["9d6a682e-36d7-46a8-ad23-b0ee86cc46b1","a177cece-7349-4c0f-b6a0-2711fc416a99"]
    #   }
    # }

    def apply
      query = DataCycleCore::Filter::Search.new(language || 'de')
      parameters.each do |key,value|
        raise "funktion #{key} is not defined for class #{query.class}" unless query.respond_to?(key)
        if value.kind_of?(Hash)
          value.each do |_, item|
            query = query.send(key,item)
          end
        else
          query = query.send(key, value)
        end
      end
      query
    end
  end
end
