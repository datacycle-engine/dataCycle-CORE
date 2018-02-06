describe('EmbeddedObject', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const option = 'Artikel'
  const cname = 'Test_' + option + '_' + Date.now()
  const zitat_headline = 'Test_Zitat_' + Date.now()
  const zitat1_headline = 'Test_Zitat1_' + Date.now()
  const zitat2_headline = 'Test_Zitat2_' + Date.now()
  const zitat3_headline = 'Test_Zitat3_' + Date.now()
  const updated_zitat_headline = 'Updated_' + zitat_headline
  const person = {
    given_name: 'Test_Given_name_' + Date.now(),
    family_name: 'Test_Family_name_' + Date.now()
  }

  it('add Zitat', function () {
    cy.createCreativeWork(cname, option).then(resp => {
      var url = resp.headers.location
      cy.visit(url).get('.flash.callout .close-button').click({
        force: true
      }).should('be.hidden')

      cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.button.addContentObject').should('be.visible').click()

      cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.content-object-item#creative_work_datahash_quotation_item_0').should('be.visible').find('.quill-editor .ql-editor').should('be.visible').type(zitat_headline)

      cy.get('.submit-edit-form').should('be.visible').click()
      cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
      cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click().should('be.hidden')
      cy.get('.detail-content-wrapper').contains(zitat_headline).should('have.length', 1)
    })
  })

  it('update Zitat', function () {
    cy.visit('/?search=' + cname).get('.flash.callout .close-button').click({
      force: true
    }).should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + cname + ') .content-link').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

    cy.get('.edit-content-link').click()
    cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

    cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.content-object-item#creative_work_datahash_quotation_item_0').should('be.visible').find('.quill-editor .ql-editor').should('be.visible').clear().type(updated_zitat_headline)

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(updated_zitat_headline).should('have.length', 1)
  })

  it('use Objectbrowser inside Zitat', function () {
    cy.visit('/?search=' + cname).get('.flash.callout .close-button').click({
      force: true
    }).should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + cname + ') .content-link').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

    cy.get('.edit-content-link').click()
    cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

    cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.content-object-item').should('be.visible').find('.object-browser[data-type="person"]').should('be.visible').find('.button#show').should('be.visible').click()
    cy.get('.object-browser-overlay:visible').should('be.visible').find('.new-item-button').should('be.visible').click()
    cy.get('.new-item:visible').should('be.visible').find('#person_datahash_given_name').should('be.visible').type(person.given_name)
    cy.get('.new-item:visible').should('be.visible').find('#person_datahash_family_name').should('be.visible').type(person.family_name + '{enter}')
    cy.get('.chosen-items:visible').should('be.visible').contains(person.given_name + ' ' + person.family_name).should('have.length', 1)
    cy.get('.object-browser-search:visible').should('be.visible').type(person.given_name + ' ' + person.family_name + '{enter}')
    cy.get('.items:not(.chosen-items):visible').contains(person.given_name + ' ' + person.family_name).should('have.length', 1)

    cy.get('.save-object-browser:visible').should('be.visible').click()
    cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.content-object-item').should('be.visible').find('.object-browser[data-type="person"]').contains(person.given_name + ' ' + person.family_name).should('have.length', 1)

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(person.given_name).should('have.length', 1)
    cy.get('.detail-content-wrapper').contains(person.family_name).should('have.length', 1)
  })

  it('remove Zitat', function () {
    cy.visit('/?search=' + cname).get('.flash.callout .close-button').click({
      force: true
    }).should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + cname + ') .content-link').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

    cy.get('.edit-content-link').click()
    cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

    cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.content-object-item').should('be.visible').find('.button.removeContentObject').should('be.visible').click()

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(updated_zitat_headline).should('have.length', 0)
  })

  it('add multiple Zitat', function () {
    cy.visit('/?search=' + cname).get('.flash.callout .close-button').click({
      force: true
    }).should('be.hidden')
    cy.get('.search-results .grid-item:contains(' + cname + ') .content-link').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

    cy.get('.edit-content-link').click()
    cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

    cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.button.addContentObject').should('be.visible').click()
    cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.content-object-item#creative_work_datahash_quotation_item_0').should('be.visible').find('.quill-editor .ql-editor').should('be.visible').type(zitat1_headline)
    cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.button.addContentObject').should('be.visible').click()
    cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.content-object-item#creative_work_datahash_quotation_item_1').should('be.visible').find('.quill-editor .ql-editor').should('be.visible').type(zitat2_headline)
    cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.button.addContentObject').should('be.visible').click()
    cy.get('.embedded-object[data-key="creative_work[datahash][quotation]"]').should('be.visible').find('.content-object-item#creative_work_datahash_quotation_item_2').should('be.visible').find('.quill-editor .ql-editor').should('be.visible').type(zitat3_headline)

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click().should('be.hidden')

    cy.get('.detail-content-wrapper').contains(zitat1_headline).should('have.length', 1)
    cy.get('.detail-content-wrapper').contains(zitat2_headline).should('have.length', 1)
    cy.get('.detail-content-wrapper').contains(zitat3_headline).should('have.length', 1)
    cy.get('.detail-content-wrapper .quotation').should('have.length', 3)
  })

})
