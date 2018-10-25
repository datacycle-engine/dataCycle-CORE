describe('DataLink', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const option = 'Artikel'
  const cname = 'Test_' + option + '_' + Date.now()
  const email = 'test_' + Date.now() + '@test.mail'
  const updated_name = 'Updated_' + cname
  var id = undefined

  it('create', function () {
    cy.createThing(cname, option).then(resp => {
      var url = resp.headers.location.replace('/edit', '')
      cy.visit(url).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit').then((path) => {
        id = path.substring(path.lastIndexOf('/') + 1)
      })

      cy.get('.detail-header-functions [data-toggle="send-link"]').click()
      cy.get('#send-link').should('be.visible').find('.new-data-link').click()
      cy.get('#data-link-overlay-new #data_link_receiver_email').should('be.visible').type(email)
      cy.get('#data-link-overlay-new #data_link_receiver_given_name').should('be.visible').type('Test')
      cy.get('#data-link-overlay-new #data_link_receiver_family_name').should('be.visible').type('Test')
      cy.get('#data-link-overlay-new #data_link_permissions_write').should('be.visible').check()
      cy.get('#data-link-overlay-new [type="submit"]').should('be.visible').click()
      cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit')
      cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

      cy.get('.detail-header-functions [data-toggle="send-link"]').click()
      cy.get('#send-link').should('be.visible').find('li:contains("' + email + '")').should('have.length', 1).then(function ($elem) {
        const url = '/data_links/' + $elem.prop('id').replace('data-link-', '')

        cy.logout()
        cy.visit(url).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
        cy.get('.headline input[type=text]').should('be.visible').should('have.value', cname).clear().type(updated_name)
        cy.get('.submit-edit-form').click()
        cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit')
        cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
      })
    })
  })

  it('lock link', function () {
    cy.visit('/things/' + id).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit')

    cy.get('.detail-header-functions [data-toggle="send-link"]').click()
    cy.get('#send-link').should('be.visible').find('li:contains("' + email + '")').should('have.length', 1).then(function ($elem) {
      const url = '/data_links/' + $elem.prop('id').replace('data-link-', '')
      $elem.find('.invalidate-data-link').click()
      cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit')
      cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

      cy.logout()
      cy.request({
        url: url,
        failOnStatusCode: false
      }).then(function (resp) {
        expect(resp.status).to.eq(403)
      })
    })
  })

  it('unlock link', function () {
    cy.visit('/things/' + id).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
    cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit')

    cy.get('.detail-header-functions [data-toggle="send-link"]').click()
    cy.get('#send-link').should('be.visible').find('li:contains("' + email + '")').should('have.length', 1).then(function ($elem) {
      const url = '/data_links/' + $elem.prop('id').replace('data-link-', '')
      const overlay_id = $elem.prop('id').replace('data-link-', 'data-link-overlay-')
      $elem.find('.send-link-button').click()

      cy.get('#' + overlay_id + ' input[value="write"]').should('be.visible').check()
      cy.get('#' + overlay_id + ' [name="data_link[valid_until]"]').should('have.length', 1).siblings('.flatpickr-input').clear().type(new Date(Date.now() + 24 * 60 * 60 * 1000).toLocaleDateString('de-DE'))
      cy.get('#' + overlay_id + ' [type="submit"]').should('be.visible').click()
      cy.location('pathname').should('match', /\/things/).should('not.contain', '/edit')
      cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

      cy.logout()
      cy.visit(url).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.get('.headline input[type=text]').should('be.visible').should('have.value', updated_name)
    })
  })
})
