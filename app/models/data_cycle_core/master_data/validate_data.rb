module MasterData

  class ValidateData

    attr_reader :error

    def initialize
      @error = { error: [], warning: []}
      return self
    end

    def valid?(data, data_type, strict = false)
      if data.blank?
        @error[:error].push("No data given.")
        return @error
      end

      template = DataCycleCore::CreativeWork.where(headline: data_type, template: true).first # ? oder definition ist direkt im Datensatz abgespeichert
      if template.blank?
        @error[:error].push("No template found.")
        return @error
      end

      validation_hash = template.metadata['validation']
      unless validation_hash['name'] == data_type
        @error[:error].push("Data and template have different types.")
        return @error
      end

      validation_object = Validators::Object.new(data,validation_hash['properties'])
      @error = validation_object.error

      if strict
        return (@error[:error].length+@error[:warning].length)==0
      else
        return @error[:error].length == 0
      end
    end


  end
end
