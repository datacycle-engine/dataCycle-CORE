describe('Publication Schedule', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const option = 'Artikel';
  const cname = 'Test_' + option + '_' + Date.now();
  const tree_label = 'ausgabekanäle';
  const publication_output_channel = 'Web';
  const publication_date = new Date(Date.now()).toLocaleDateString('de-DE', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric'
  });
  let id = undefined;

  it('add publication schedule', function () {
    cy.createCreativeWork(cname, option).then(resp => {
      let url = resp.headers.location;
      id = url.substr(url.indexOf('creative_works/') + 15, 36);
      cy.visit(url).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden');

      cy.get('.embedded-object[data-key="creative_work[datahash][publication_schedule]"]').should('be.visible').find('.button.addContentObject').should('be.visible').click();

      cy.get('.embedded-object[data-key="creative_work[datahash][publication_schedule]"]').should('be.visible').find('.content-object-item#creative_work_datahash_publication_schedule_item_0').should('be.visible').find('.output_channels .select2-search__field').should('be.visible').type(publication_output_channel).parents('.v-select').find('.select2-dropdown .select2-results__option:contains("' + publication_output_channel + '")').should('be.visible').click();

      cy.get('.embedded-object[data-key="creative_work[datahash][publication_schedule]"]').should('be.visible').find('.content-object-item#creative_work_datahash_publication_schedule_item_0').should('be.visible').find('.publish_at .flatpickr-input:visible').should('be.visible').type(publication_date);

      cy.get('.submit-edit-form').should('be.visible').click();
      cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit');
      cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden');
      cy.get('.detail-content-wrapper').contains(publication_date).should('have.length', 1);
    })
  })

  it('show active schedules', function () {
    cy.visit('/publications');

    cy.get('#primary_nav_wrap li.filter[data-tree-label="' + tree_label + '"]').should('be.visible').find('label:contains("' + publication_output_channel + '")').click({
      force: true
    });

    cy.get('#search').should('be.visible').type(cname + '{enter}');
    cy.location('pathname').should('match', /\/publications/);

    cy.get('.publications-list').should('be.visible').contains(cname).should('have.length', 1);
  })
})
