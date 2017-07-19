module DataCycleCore
  class DataHashService

    #todo make this more fancy
    def self.flatten_datahash_value(datahash,debug=false)

      if datahash.key?(:quotation) && !datahash[:quotation].empty?
        datahash[:quotation] = datahash[:quotation].values
      end

      if datahash.key?(:website) && !datahash[:website].empty?
        datahash[:website] = datahash[:website].values
      end

      if datahash.key?(:mobileApplication) && !datahash[:mobileApplication].empty?
        datahash[:mobileApplication] = datahash[:mobileApplication].values
      end

      if datahash.key?(:timelineItem) && !datahash[:timelineItem].empty?
        datahash[:timelineItem] = datahash[:timelineItem].values
      end

      if datahash.key?(:suggestedAnswer) && !datahash[:suggestedAnswer].empty?
        datahash[:suggestedAnswer] = datahash[:suggestedAnswer].values
      end

      if datahash.key?(:totalTime) && !datahash[:totalTime].blank?
        datahash[:totalTime] = datahash[:totalTime].to_i
      end

      if datahash.key?(:event) && !datahash[:event].empty?
        datahash[:event] = datahash[:event].values
      end

      if datahash.key?(:recipeComponent) && !datahash[:recipeComponent].empty?
        temp_recipeComponent= []

        datahash[:recipeComponent].values.each do |component|
          temp = component
          if temp.key?(:totalTime) && !temp[:totalTime].blank?
            temp[:totalTime] = temp[:totalTime].to_i
          end
          temp_recipeComponent.push(temp)
        end
        datahash[:recipeComponent] = temp_recipeComponent
      end

      if datahash.key?(:question) && !datahash[:question].empty?

        temp_question = []

        datahash[:question].values.each do |question|
          temp = question
          if temp.key?(:suggestedAnswer) && !temp[:suggestedAnswer].empty?
            temp[:suggestedAnswer] = temp[:suggestedAnswer].values
          end
          if temp.key?(:acceptedAnswer) && !temp[:acceptedAnswer].empty?
            temp[:acceptedAnswer] = temp[:acceptedAnswer].values
          end
          temp_question.push(temp)
        end
        datahash[:question] = temp_question
      end

      if debug == true
        raise datahash.inspect
      end

      return datahash

    end

  end

end