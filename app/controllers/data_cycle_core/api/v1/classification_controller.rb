module DataCycleCore
  class Api::V1::ClassificationController < Api::V1::ApiBaseController
    @@default_per = 300

    def index
      # still not final!! external_source_id identified via 'Administrator-account'
      # external_source sub-query
      external_source_id = Arel::SelectManager.new
        .project(DataCycleCore::ExternalSource.arel_table[:id])
        .from(DataCycleCore::ExternalSource.arel_table)
        .join(DataCycleCore::UseCase.arel_table)
        .on(DataCycleCore::ExternalSource.arel_table[:id].eq(DataCycleCore::UseCase.arel_table[:external_source_id]))
        .join(DataCycleCore::User.arel_table)
        .on(DataCycleCore::UseCase.arel_table[:user_id].eq(DataCycleCore::User.arel_table[:id]))
        .where(DataCycleCore::User.arel_table[:name].eq(Arel::Nodes.build_quoted('Administrator')))

      # lables sub-query
      lables = Arel::SelectManager.new
        .project(DataCycleCore::ClassificationTreeLabel.arel_table[:name])
        .from(DataCycleCore::ClassificationTreeLabel.arel_table)
        .where(DataCycleCore::ClassificationTreeLabel.arel_table[:external_source_id].eq(nil)
          .or(DataCycleCore::ClassificationTreeLabel.arel_table[:external_source_id].in(external_source_id)))

      # main query
      query = DataCycleCore::ClassificationTree
        .joins(:classification_tree_label, :sub_classification_alias)
        .joins(
          DataCycleCore::ClassificationTree.arel_table.join(DataCycleCore::ClassificationAlias.arel_table)
          .on(DataCycleCore::ClassificationTree.arel_table[:classification_alias_id].eq(DataCycleCore::ClassificationAlias.arel_table[:id]))
          .join_sources
        )
        .includes([:sub_classification_alias, :classification_tree_label]) # eager loading to avoid (n+1) loading in iteration
        .where(DataCycleCore::ClassificationTreeLabel.arel_table[:name].in(lables))
        .where(DataCycleCore::ClassificationTreeLabel.arel_table[:external_source_id].eq(nil)
          .or(DataCycleCore::ClassificationTreeLabel.arel_table[:external_source_id].in(external_source_id)))
        .order([classification_tree_label_id: :asc])

      @per = params[:per] unless params[:per].blank?
      @per ||= @@default_per

      @total = query.count
      pages = @total.fdiv(@per.to_i).ceil

      unless params[:page].blank?
        @page = params[:page]
        @page = pages if params[:page].to_i > pages
      end
      @page ||= 1

      @classification_aliases = query.page(@page).per(@per)
    end
  end
end
