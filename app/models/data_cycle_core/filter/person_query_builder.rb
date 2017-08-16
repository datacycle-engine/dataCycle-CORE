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

      def join_classification_alias2
        Arel::SelectManager.new.
          project(person[:id]).
          from(person).
          where(person[:template].eq(false)).
          join(person_translation).
            on(person[:id].eq(person_translation[:person_id])).
          where(person_translation[:locale].eq(quoted(@locale))).
          join(classification_person).
            on(person[:id].eq(classification_person[:person_id])).
          join(classification).
            on(classification_person[:classification_id].eq(classification[:id])).
          join(classification_group).
            on(classification[:id].eq(classification_group[:classification_id])).
          join(classification_alias).
            on(classification_group[:classification_alias_id].eq(classification_alias[:id]))
      end

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
        Person::Translation.arel_table
      end

      def classification_person
        ClassificationPerson.arel_table
      end

    end
  end
end
