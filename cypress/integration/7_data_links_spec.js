describe('DataLink', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const option = 'Artikel'
  const cname = 'Test_' + option + '_' + Date.now()
  const email = 'test_' + Date.now() + '@test.mail'
  const updated_name = 'Updated_' + cname

  it('create', function () {
    cy.createCreativeWork(cname, option)

    cy.get('#search').type(cname + '{enter}', {
      force: true
    }).get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).click()

    cy.get('.detail-header-functions [data-toggle="send-link"]').click()
    cy.get('#send-link').should('be.visible').find('.new-data-link').click()
    cy.get('#data-link-overlay-new #data_link_receiver_email').should('be.visible').type(email)
    cy.get('#data-link-overlay-new #data_link_receiver_given_name').should('be.visible').type('Test')
    cy.get('#data-link-overlay-new #data_link_receiver_family_name').should('be.visible').type('Test')
    cy.get('#data-link-overlay-new #data_link_permissions_write').should('be.visible').check()
    cy.get('#data-link-overlay-new [type="submit"]').should('be.visible').click()
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

    cy.get('.detail-header-functions [data-toggle="send-link"]').click()
    cy.get('#send-link').should('be.visible').find('.email:contains("' + email + '")').should('have.length', 1)
  })

  it('test link', function () {
    cy.get('#search').type(cname + '{enter}', {
      force: true
    }).get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).click()
    cy.get('.detail-header-functions [data-toggle="send-link"]').click()
    cy.get('#send-link').should('be.visible').find('li:contains("' + email + '")').should('have.length', 1).then(function ($elem) {
      const url = '/data_links/' + $elem.prop('id').replace('data-link-', '')

      cy.logout()
      cy.visit(url)
      cy.get('.headline input[type=text]').should('be.visible').should('have.value', cname).clear().type(updated_name)
      cy.get('.submit-edit-form').click()
      cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()
    })
  })

  //  TODO: active only for core tests
  // it('test link finalization', function () {
  //   cy.get('#search').type(cname + '{enter}', {
  //     force: true
  //   }).get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).click()
  //   cy.get('.detail-header-functions [data-toggle="send-link"]').click()
  //   cy.get('#send-link').should('be.visible').find('li:contains("' + email + '")').should('have.length', 1).then(function ($elem) {
  //     const url = '/data_links/' + $elem.prop('id').replace('data-link-', '')
  //
  //     cy.logout()
  //     cy.visit(url)
  //     cy.get('.headline input[type=text]').should('be.visible').should('have.value', updated_name).clear().type(cname)
  //     cy.get('input#finalize').should('be.visible').check()
  //     cy.get('.submit-edit-form').click()
  //     cy.get('.confirmation').should('be.visible').find('.ok').click()
  //     cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()
  //
  //     cy.get('.edit-content-link').should('have.length', 0)
  //   })
  // })

  it('lock link', function () {
    cy.get('#search').type(updated_name + '{enter}', {
      force: true
    }).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 1).click()
    cy.get('.detail-header-functions [data-toggle="send-link"]').click()
    cy.get('#send-link').should('be.visible').find('li:contains("' + email + '")').should('have.length', 1).then(function ($elem) {
      const url = '/data_links/' + $elem.prop('id').replace('data-link-', '')
      $elem.find('.invalidate-data-link').click()
      cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

      cy.logout()
      cy.request({
        url: url,
        failOnStatusCode: false
      }).then(function (resp) {
        expect(resp.status).to.eq(500)
      })

    })
  })

  it('unlock link', function () {
    cy.get('#search').type(updated_name + '{enter}', {
      force: true
    }).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 1).click()
    cy.get('.detail-header-functions [data-toggle="send-link"]').click()
    cy.get('#send-link').should('be.visible').find('li:contains("' + email + '")').should('have.length', 1).then(function ($elem) {
      const url = '/data_links/' + $elem.prop('id').replace('data-link-', '')
      const overlay_id = $elem.prop('id').replace('data-link-', 'data-link-overlay-')
      $elem.find('.send-link-button').click()

      cy.get('#' + overlay_id + ' input[value="write"]').should('be.visible').check()
      cy.get('#' + overlay_id + ' [name="data_link[valid_until]"]').should('have.length', 1).siblings('.flatpickr-input').clear().type(new Date(Date.now() + 24 * 60 * 60 * 1000).toLocaleDateString())
      cy.get('#' + overlay_id + ' [type="submit"]').should('be.visible').click()
      cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

      cy.logout()
      cy.visit(url)
      cy.get('.headline input[type=text]').should('be.visible').should('have.value', updated_name)
    })
  })
})
