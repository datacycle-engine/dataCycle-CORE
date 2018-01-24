describe('WatchList', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  const name = 'Test_Watch_List_' + Date.now()
  const updated_name = 'Updated_' + name
  const option = 'Artikel'
  const cname = 'Test_' + option + '_' + Date.now()

  it('create', function () {
    cy.visit('/').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('#add-to-watchlist-link').click()
    cy.get('#header-menu_new_watch_list #header-menu_watch_list_headline').type(name + '{enter}', {
      force: true
    })
    cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + name + '")').click({
      force: true
    })
    cy.get('.detail-header-wrapper').should(($elem) => {
      expect($elem.first()).to.contain(name)
    })
  })

  it('update', function () {
    cy.visit('/').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('#add-to-watchlist-link').click()
    cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + name + '")').click({
      force: true
    })
    cy.get('.detail-header-wrapper').should(($elem) => {
      expect($elem.first()).to.contain(name)
    })

    cy.get('.edit-content-link').click()
    cy.get('.headline input[type=text]').should('be.visible').should('have.value', name).clear().type(updated_name)
    cy.get('.submit-edit-form').click()
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()

    cy.get('#add-to-watchlist-link').click()
    cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + updated_name + '")').should('have.length', 1)
  })

  it('add artikel', function () {
    cy.createCreativeWork(cname, option)
    cy.visit('/').get('.flash.callout .close-button').click({
      force: true
    })

    cy.get('#search').type(cname + '{enter}', {
      force: true
    }).get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).find('.watch-lists-link').click()
    cy.get('.search-results .grid-item:contains(' + cname + ') .watch-lists .watch-list-item .watchlist-headline .add-to-watchlist-link:contains("' + updated_name + '")').click()

    cy.get('[data-toggle="watch-lists-for-user"]').click()
    cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + updated_name + '")').click({
      force: true
    })

    cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1)
  })

  it('remove artikel', function () {
    cy.visit('/').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('#search').type(cname + '{enter}', {
      force: true
    }).get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).find('.watch-lists-link').click()
    cy.get('.search-results .grid-item:contains(' + cname + ') .watch-lists .watch-list-item:contains("' + updated_name + '")').find('.remove-from-watchlist-link').click()
    cy.get('.confirmation').should('be.visible').find('.accept-confirmation').click()

    cy.get('[data-toggle="watch-lists-for-user"]').click()
    cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + updated_name + '")').click({
      force: true
    })
    cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 0)
  })

  it('delete', function () {
    cy.visit('/').get('.flash.callout .close-button').click({
      force: true
    })
    cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + updated_name + '")').click({
      force: true
    })
    cy.get('.detail-header-wrapper .edit [data-method=delete]').should('be.visible').click()
    cy.get('.confirmation').should('be.visible').find('.accept-confirmation').click()
    cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()
    cy.get('#add-to-watchlist-link').click()
    cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + updated_name + '")').should('have.length', 0)
  })

})
