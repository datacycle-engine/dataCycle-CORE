describe('WatchList', function () {
  // beforeEach(function () {
  //   cy.login('admin')
  // })

  // const name = 'Test_Watch_List_' + Date.now()
  // const updated_name = 'Updated_' + name
  // const option = 'Artikel'
  // const cname = 'Test_' + option + '_' + Date.now()
  // var id = undefined

  // it('create', function () {
  //   cy.visit('/').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
  //   cy.get('#add-to-watchlist-link').click()
  //   cy.get('#header-menu_new_watch_list #header-menu_watch_list_headline').type(name + '{enter}')
  //   cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + name + '")').click({
  //     force: true
  //   })
  //   cy.location('pathname').should('match', /\/watch_lists/).then((path) => {
  //     id = path.substring(path.lastIndexOf('/') + 1)
  //   })

  //   cy.get('.detail-header-wrapper').should(($elem) => {
  //     expect($elem.first()).to.contain(name)
  //   })
  // })

  // it('update', function () {
  //   cy.visit('/watch_lists/' + id + '/edit').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
  //   cy.location('pathname').should('match', /\/watch_lists\/.*\/edit/)

  //   cy.get('.headline input[type=text]').should('be.visible').should('have.value', name).clear().type(updated_name)
  //   cy.get('.submit-edit-form').click()
  //   cy.location('pathname').should('match', /\/watch_lists/)
  //   cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

  //   cy.get('#add-to-watchlist-link').click()
  //   cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + updated_name + '")').should('have.length', 1)
  // })

  // it('add artikel', function () {
  //   cy.createCreativeWork(cname, option)
  //   cy.visit('/?f%5Bs%5D%5Bn%5D=Suchbegriff&f%5Bs%5D%5Bt%5D=fulltext_search&f%5Bs%5D%5Bv%5D=' + cname).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')

  //   cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).find('.watch-lists-link').click()
  //   cy.get('.search-results .grid-item:contains(' + cname + ') .watch-lists .watch-list-item .watchlist-headline .add-to-watchlist-link:contains("' + updated_name + '")').click()

  //   cy.get('[data-toggle="watch-lists-for-user"]').click()
  //   cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + updated_name + '")').click({
  //     force: true
  //   })
  //   cy.location('pathname').should('match', /\/watch_lists/)

  //   cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1)
  // })

  // it('test json API', function () {
  //   cy.request('/api/v2/collections/' + id).then((response) => {
  //     expect(response.body).to.have.property('collection')
  //     expect(response.body.collection).to.have.property('id', id)
  //     expect(response.body.collection).to.have.property('name', updated_name)
  //     expect(response.body.collection).to.have.property('items')
  //     expect(response.body.collection.items).to.have.length(1)
  //     expect(response.body.collection.items[0]).to.have.property('contentType', option)
  //     expect(response.body.collection.items[0]).to.have.property('headline', cname)
  //   })
  // })

  // it('remove artikel', function () {
  //   cy.visit('/?f%5Bs%5D%5Bn%5D=Suchbegriff&f%5Bs%5D%5Bt%5D=fulltext_search&f%5Bs%5D%5Bv%5D=' + cname).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
  //   cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 1).find('.watch-lists-link').click()
  //   cy.get('.search-results .grid-item:contains(' + cname + ') .watch-lists .watch-list-item:contains("' + updated_name + '")').find('.remove-from-watchlist-link').click()
  //   cy.get('.confirmation-modal').should('be.visible').find('.confirmation-confirm').click()

  //   cy.get('[data-toggle="watch-lists-for-user"]').click()
  //   cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + updated_name + '")').click({
  //     force: true
  //   })
  //   cy.location('pathname').should('match', /\/watch_lists/)

  //   cy.get('.search-results .grid-item:contains(' + cname + ')').should('have.length', 0)
  // })

  // it('delete', function () {
  //   cy.visit('/watch_lists/' + id).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
  //   cy.location('pathname').should('match', /\/watch_lists/)

  //   cy.get('.detail-header-wrapper .edit [data-method=delete]').should('be.visible').click()
  //   cy.get('.confirmation-modal').should('be.visible').find('.confirmation-confirm').click()
  //   cy.location('pathname').should('match', /\/watch_lists/)
  //   cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

  //   cy.get('#add-to-watchlist-link').click()
  //   cy.get('#watch-lists-for-user').find('.watch-list-item .watchlist-link:contains("' + updated_name + '")').should('have.length', 0)
  // })

})
