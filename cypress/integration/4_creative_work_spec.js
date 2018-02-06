describe('CreativeWork', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  context('Artikel', function () {
    const option = 'Artikel'
    const name = 'Test_' + option + '_' + Date.now()
    const updated_name = 'Updated_' + name
    var id = undefined

    it('create', function () {
      cy.visit('/?search=' + name).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.get('#new-object-circle').click()
      cy.get('#new-object .option[data-open="' + option + '"]').then(function ($elem) {
        cy.expect($elem).to.be.visible
        $elem.click()
        cy.get('#' + $elem.data('open')).should('be.visible')
        cy.get('#' + $elem.data('open') + ' input[type=text]').clear().type(name)
        cy.get('#' + $elem.data('open')).find('form').submit()
        cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)
        cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click()

        cy.get('.edit-content-form').then(($elem) => {
          id = $elem.prop('action').substring($elem.prop('action').lastIndexOf('/') + 1)
          expect(id).to.have.length(36)
        })

        cy.get('.headline input[type=text]').should('have.value', name)
        cy.get('.edit-header-functions .discard').click()
        cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

        cy.get('.detail-header-wrapper').should(($elem) => {
          expect($elem.first()).to.contain(name)
        })
        cy.visit('/?search=' + name).get('.search-results .grid-item:contains(' + name + ')').should('have.length', 1)
      })
    })

    it('update', function () {
      cy.visit('/creative_works/' + id + '/edit').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

      cy.get('.headline input[type=text]').should('be.visible').should('have.value', name).clear().type(updated_name)
      cy.get('.submit-edit-form').click()
      cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
      cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')
      cy.get('.detail-header-wrapper').contains(updated_name).should('have.length', 1)
    })

    it('test json API', function () {
      cy.request('/api/v1/creative_works/' + id).then((response) => {
        expect(response.body).to.have.property('contentType', option)
        expect(response.body).to.have.property('headline', updated_name)
      })
    })

    it('test contents search API', function () {
      cy.request('/api/v1/contents/search?search=' + updated_name).then((response) => {
        expect(response.body).to.have.property('contents')
        expect(response.body.contents).to.have.length(1)
        expect(response.body.contents[0]).to.have.property('contentType', option)
        expect(response.body.contents[0]).to.have.property('headline', updated_name)
      })
    })

    it('delete', function () {
      cy.visit('/creative_works/' + id).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

      cy.get('.delete-content-link').click()
      cy.get('.confirmation-modal').should('be.visible').find('.confirmation-confirm').click()
      cy.location('pathname').should('eq', '/')

      cy.visit('/?search=' + updated_name).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 0)
    })

  })

  context('Angebot', function () {
    const option = 'Angebot'
    const name = option + '_Test_' + Date.now()
    const updated_name = name + '_updated'
    var id = undefined

    it('create', function () {
      cy.visit('/?search=' + name).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.get('#new-object-circle').click()
      cy.get('#new-object .option[data-open="' + option + '"]').then(function ($elem) {
        expect($elem).to.be.visible
        $elem.click()
        cy.get('#' + $elem.data('open')).should('be.visible')
        cy.get('#' + $elem.data('open') + ' input[type=text]').clear().type(name)
        cy.get('#' + $elem.data('open')).find('form').submit()
        cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)
        cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

        cy.get('.edit-content-form').then(($elem) => {
          id = $elem.prop('action').substring($elem.prop('action').lastIndexOf('/') + 1)
          expect(id).to.have.length(36)
        })

        cy.get('.headline input[type=text]').should('have.value', name)
        cy.get('.edit-header-functions .discard').click()
        cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

        cy.get('.detail-header-wrapper').should(($elem) => {
          expect($elem.first()).to.contain(name)
        })
        cy.visit('/?search=' + name).get('.search-results .grid-item:contains(' + name + ')').should('have.length', 1)
      })
    })

    it('update', function () {
      cy.visit('/creative_works/' + id + '/edit').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

      cy.get('.headline input[type=text]').should('be.visible').should('have.value', name).clear().type(updated_name)

      cy.get('.submit-edit-form').click()
      cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
      cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

      cy.get('.detail-header-wrapper').contains(updated_name).should('have.length', 1)
    })

    it('test json API', function () {
      cy.request('/api/v1/creative_works/' + id).then((response) => {
        expect(response.body).to.have.property('contentType', option)
        expect(response.body).to.have.property('headline', updated_name)
      })
    })

    it('test contents search API', function () {
      cy.request('/api/v1/contents/search?search=' + updated_name).then((response) => {
        expect(response.body).to.have.property('contents')
        expect(response.body.contents).to.have.length(1)
        expect(response.body.contents[0]).to.have.property('contentType', option)
        expect(response.body.contents[0]).to.have.property('headline', updated_name)
      })
    })

    it('delete', function () {
      cy.visit('/creative_works/' + id).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

      cy.get('.delete-content-link').click()
      cy.get('.confirmation-modal').should('be.visible').find('.confirmation-confirm').click()
      cy.location('pathname').should('eq', '/')

      cy.visit('/?search=' + updated_name).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 0)
    })
  })

  context('SocialMediaPosting', function () {
    const option = 'SocialMediaPosting'
    const name = option + '_Test_' + Date.now()
    const updated_name = name + '_updated'
    var id = undefined

    it('create', function () {
      cy.visit('/?search=' + name).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.get('#new-object-circle').click()
      cy.get('#new-object .option[data-open="' + option + '"]').then(function ($elem) {
        expect($elem).to.be.visible
        $elem.click()
        cy.get('#' + $elem.data('open')).should('be.visible')
        cy.get('#' + $elem.data('open') + ' input[type=text]').clear().type(name)
        cy.get('#' + $elem.data('open')).find('form').submit()
        cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)
        cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

        cy.get('.edit-content-form').then(($elem) => {
          id = $elem.prop('action').substring($elem.prop('action').lastIndexOf('/') + 1)
          expect(id).to.have.length(36)
        })

        cy.get('.headline input[type=text]').should('have.value', name)
        cy.get('.edit-header-functions .discard').click()
        cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

        cy.get('.detail-header-wrapper').should(($elem) => {
          expect($elem.first()).to.contain(name)
        })
        cy.visit('/?search=' + name).get('.search-results .grid-item:contains(' + name + ')').should('have.length', 1)
      })
    })

    it('update', function () {
      cy.visit('/creative_works/' + id + '/edit').get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.location('pathname').should('match', /\/creative_works\/.*\/edit/)

      cy.get('.headline input[type=text]').should('be.visible').should('have.value', name).clear().type(updated_name)
      cy.get('.submit-edit-form').click()
      cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')
      cy.get('.flash.callout').should('be.visible').should('have.class', 'success').find('.close-button').click().should('be.hidden')

      cy.get('.detail-header-wrapper').contains(updated_name).should('have.length', 1)
    })

    it('test json API', function () {
      cy.request('/api/v1/creative_works/' + id).then((response) => {
        expect(response.body).to.have.property('contentType', option)
        expect(response.body).to.have.property('headline', updated_name)
      })
    })

    it('test contents search API', function () {
      cy.request('/api/v1/contents/search?search=' + updated_name).then((response) => {
        expect(response.body).to.have.property('contents')
        expect(response.body.contents).to.have.length(1)
        expect(response.body.contents[0]).to.have.property('contentType', option)
        expect(response.body.contents[0]).to.have.property('headline', updated_name)
      })
    })

    it('delete', function () {
      cy.visit('/creative_works/' + id).get('.flash.callout .close-button').should('be.visible').click().should('be.hidden')
      cy.location('pathname').should('match', /\/creative_works/).should('not.contain', '/edit')

      cy.get('.delete-content-link').click()
      cy.get('.confirmation-modal').should('be.visible').find('.confirmation-confirm').click()
      cy.location('pathname').should('eq', '/')

      cy.visit('/?search=' + updated_name).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 0)
    })
  })
})
