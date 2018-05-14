module DataCycleCore
  class Ability
    CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze

    include CanCan::Ability
    include DataCycleCore::Abilities

    def initialize(user, session = {})
      if user
        can :show, :all

        (user.role&.rank.to_i + 1).times do |rank|
          begin
            merge DataCycleCore::Abilities.const_get("rank_#{rank}_ability".classify).new(user, session)
          rescue NameError
            nil
          end
        end

        # special admin privileges
        can :manage, :dash_board if user.has_rank?(10) && (user.email =~ /@pixelpoint\.at/ || user.email =~ /@datacycle\.at/)
      end
    end
  end
end
