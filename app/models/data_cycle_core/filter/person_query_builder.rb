module DataCycleCore
  module Filter
    class PersonQueryBuilder < QueryBuilder

      def initialize(locale = 'de', query = nil)
        @locale = locale
        @query = query || Person.unscoped.distinct.
          where(template: false).
          joins(
            person.join(person_translation).
            on(person[:id].eq(person_translation[:person_id])).
            join_sources
          ).where(person_translation[:locale].eq(quoted(@locale)))
      end

      def fulltext_search(name)
        query = join_person_translation
        manager = query.
          where(person[:givenName].matches("%#{name}%").
            or(person[:familyName].matches("%#{name}%"))
          )

        reflect(
          @query.where(
            person[:id].in(manager)
          )
        )
      end

      def with_classification_alias_ids(ids = nil)
        manager = create_classification_alias_recursion(ids)
        # get everything including parents (or-clause)
        reflect(
          @query.where(person[:id].in(manager))
        )
      end

    private

      def join_person_translation
        Arel::SelectManager.new.
          project(person[:id]).
          from(person).
          where(person[:template].eq(false)).
          join(person_translation)
            .on(person[:id].eq(person_translation[:person_id]))
      end

    # define Arel-tables
      def person
        Person.arel_table
      end

      def person_translation
        PersonTranslation.arel_table
      end

    end
  end
end
