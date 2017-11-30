module DataCycleCore
  class BackendController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user!   # from devise (authenticate)
    authorize_resource :class => false  # from cancancan (authorize)

    def index
      @dataCycleObjects = get_filtered_results

      @creativeWork = CreativeWork.new
    end

    def settings
    end

    def vue

    end

    private

    def parse_classifications(class_array)
      grouping_class = {}
      class_array.each do |class_id|
        name = DataCycleCore::ClassificationAlias.find(class_id).classification_tree_label.name
        grouping_class[name] ||= []
        grouping_class[name].push(class_id)
      end
      grouping_class
    end

  end
end
