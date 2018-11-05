describe('Embedded Object', function () {
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
  var id = undefined

  it('add Quote', function () {
    cy.createThing(cname, option).then(resp => {
      var url = resp.headers.location
      id = url.substr(url.indexOf('things/') + 15, 36)
      cy.visit(url).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')

      cy.get('.embedded-object[data-key="thing[datahash][quotation]"]').should('be.visible').find('.button.addContentObject').should('be.visible').click()

      cy.get('.embedded-object[data-key="thing[datahash][quotation]"]').should('be.visible').find('.content-object-item#thing_datahash_quotation_item_0').should('be.visible').find('.quill-editor .ql-editor').should('be.visible').type(zitat_headline)

      cy.get('.submit-edit-form').should('be.visible').click()
      cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit')
      cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
      cy.get('.detail-content-wrapper').contains(zitat_headline).should('have.length', 1)
    })
  })

  it('update Quote', function () {
    cy.visit('/things/' + id + '/edit').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.location('pathname').should('match', /\/things\/.*\/edit/)

    cy.get('.embedded-object[data-key="thing[datahash][quotation]"]').should('be.visible').find('.content-object-item#thing_datahash_quotation_item_0').should('be.visible').find('.quill-editor .ql-editor').should('be.visible').clear().type(updated_zitat_headline)

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(updated_zitat_headline).should('have.length', 1)
  })

  it('remove Quote', function () {
    cy.visit('/things/' + id + '/edit').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.location('pathname').should('match', /\/things\/.*\/edit/)

    cy.get('.embedded-object[data-key="thing[datahash][quotation]"]').should('be.visible').find('.content-object-item').should('be.visible').find('.button.removeContentObject').should('be.visible').click()

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
    cy.get('.detail-content-wrapper').contains(updated_zitat_headline).should('have.length', 0)
  })

  it('add multiple Quotes', function () {
    cy.visit('/things/' + id + '/edit').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.location('pathname').should('match', /\/things\/.*\/edit/)

    cy.get('.embedded-object[data-key="thing[datahash][quotation]"]').should('be.visible').find('.button.addContentObject').should('be.visible').click()
    cy.get('.embedded-object[data-key="thing[datahash][quotation]"]').should('be.visible').find('.content-object-item#thing_datahash_quotation_item_0').should('be.visible').find('.quill-editor .ql-editor').should('be.visible').type(zitat1_headline)
    cy.get('.embedded-object[data-key="thing[datahash][quotation]"]').should('be.visible').find('.button.addContentObject').should('be.visible').click()
    cy.get('.embedded-object[data-key="thing[datahash][quotation]"]').should('be.visible').find('.content-object-item#thing_datahash_quotation_item_1').should('be.visible').find('.quill-editor .ql-editor').should('be.visible').type(zitat2_headline)
    cy.get('.embedded-object[data-key="thing[datahash][quotation]"]').should('be.visible').find('.button.addContentObject').should('be.visible').click()
    cy.get('.embedded-object[data-key="thing[datahash][quotation]"]').should('be.visible').find('.content-object-item#thing_datahash_quotation_item_2').should('be.visible').find('.quill-editor .ql-editor').should('be.visible').type(zitat3_headline)

    cy.get('.submit-edit-form').should('be.visible').click()
    cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit')
    cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

    cy.get('.detail-content-wrapper').contains(zitat1_headline).should('have.length', 1)
    cy.get('.detail-content-wrapper').contains(zitat2_headline).should('have.length', 1)
    cy.get('.detail-content-wrapper').contains(zitat3_headline).should('have.length', 1)
    cy.get('.detail-content-wrapper .quotation').should('have.length', 3)
  })

})
