module DataCycleCore
  module Filter
    class PersonQueryBuilder < QueryBuilder

      def initialize(query = nil, language = nil)
        @language = language
        @query = query
        @query ||= Person.unscoped.distinct.
          where(template: false).
          joins(person.
            join(person_translation).
            on(person[:id].
            eq(person_translation[:person_id])).
            join_sources
          )
      end

      def with_locale(language)
        reflect(
          @query.where(
            person_translation[:locale].eq(quoted(language.to_s))
          )
        )
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

      def reflect(query)
        self.class.new(query, @language)
      end


    end
  end
end
