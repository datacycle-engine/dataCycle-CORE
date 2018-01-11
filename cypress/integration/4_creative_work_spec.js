describe('CreativeWork', function () {
  beforeEach(function () {
    cy.login('admin')
  })

  context('Artikel', function () {
    const option = 'Artikel'
    const name = 'Test_' + option + '_' + Date.now()
    const updated_name = 'Updated_' + name

    it('create', function () {
      cy.get('#search').type(name + '{enter}', {
        force: true
      })
      cy.get('#new-object-circle').click()
      cy.get('#new-object .option[data-open="' + option + '"]').then(function ($elem) {
        cy.expect($elem).to.be.visible
        $elem.click()
        cy.get('#' + $elem.data('open')).should('be.visible')
        cy.get('#' + $elem.data('open') + ' input[type=text]').clear().type(name)
        cy.get('#' + $elem.data('open')).find('form').submit()
        cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()
        cy.get('.headline input[type=text]').should('have.value', name)
        cy.get('.edit-header-functions .discard').click()
        cy.get('.detail-header-wrapper').should(($elem) => {
          expect($elem.first()).to.contain(name)
        })
        cy.visit('/').get('#search').type(name + '{enter}', {
          force: true
        }).get('.search-results .grid-item:contains(' + name + ')').should('have.length', 1)
      })
    })

    it('update', function () {
      cy.get('#search').type(name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + name + ') .content-link').should('be.visible').click()
      cy.get('.edit-content-link').click()
      cy.get('.headline input[type=text]').should('be.visible').should('have.value', name).clear().type(updated_name)
      cy.get('.submit-edit-form').click()
      cy.visit('/').get('#search').type(updated_name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 1)
    })

    it('delete', function () {
      cy.get('#search').type(updated_name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + updated_name + ') .content-link').should('be.visible').click()
      cy.get('.delete-content-link').click()
      cy.visit('/').get('#search').type(updated_name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 0)
    })

  })

  context('Angebot', function () {
    const option = 'Angebot'
    const name = option + '_Test_' + Date.now()
    const updated_name = name + '_updated'

    it('create', function () {
      cy.get('#search').type(name + '{enter}', {
        force: true
      })
      cy.get('#new-object-circle').click()
      cy.get('#new-object .option[data-open="' + option + '"]').then(function ($elem) {
        expect($elem).to.be.visible
        $elem.click()
        cy.get('#' + $elem.data('open')).should('be.visible')
        cy.get('#' + $elem.data('open') + ' input[type=text]').clear().type(name)
        cy.get('#' + $elem.data('open')).find('form').submit()
        cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()
        cy.get('.headline input[type=text]').should('have.value', name)
        cy.get('.edit-header-functions .discard').click()
        cy.get('.detail-header-wrapper').should(($elem) => {
          expect($elem.first()).to.contain(name)
        })
        cy.visit('/').get('#search').type(name + '{enter}', {
          force: true
        }).get('.search-results .grid-item:contains(' + name + ')').should('have.length', 1)
      })
    })

    it('update', function () {
      cy.get('#search').type(name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + name + ') .content-link').should('be.visible').click()
      cy.get('.edit-content-link').click()
      cy.get('.headline input[type=text]').should('be.visible').should('have.value', name).clear().type(updated_name)
      cy.get('.submit-edit-form').click()
      cy.visit('/').get('#search').type(updated_name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 1)
    })

    it('delete', function () {
      cy.get('#search').type(updated_name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + updated_name + ') .content-link').should('be.visible').click()
      cy.get('.delete-content-link').click()
      cy.visit('/').get('#search').type(updated_name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 0)
    })
  })

  context('SocialMediaPosting', function () {
    const option = 'SocialMediaPosting'
    const name = option + '_Test_' + Date.now()
    const updated_name = name + '_updated'

    it('create', function () {
      cy.get('#search').type(name + '{enter}', {
        force: true
      })
      cy.get('#new-object-circle').click()
      cy.get('#new-object .option[data-open="' + option + '"]').then(function ($elem) {
        expect($elem).to.be.visible
        $elem.click()
        cy.get('#' + $elem.data('open')).should('be.visible')
        cy.get('#' + $elem.data('open') + ' input[type=text]').clear().type(name)
        cy.get('#' + $elem.data('open')).find('form').submit()
        cy.get('.flash.callout').should('have.class', 'success').find('.close-button').click()
        cy.get('.headline input[type=text]').should('have.value', name)
        cy.get('.edit-header-functions .discard').click()
        cy.get('.detail-header-wrapper').should(($elem) => {
          expect($elem.first()).to.contain(name)
        })
        cy.visit('/').get('#search').type(name + '{enter}', {
          force: true
        }).get('.search-results .grid-item:contains(' + name + ')').should('have.length', 1)
      })
    })

    it('update', function () {
      cy.get('#search').type(name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + name + ') .content-link').should('be.visible').click()
      cy.get('.edit-content-link').click()
      cy.get('.headline input[type=text]').should('be.visible').should('have.value', name).clear().type(updated_name)
      cy.get('.submit-edit-form').click()
      cy.visit('/').get('#search').type(updated_name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 1)
    })

    it('delete', function () {
      cy.get('#search').type(updated_name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + updated_name + ') .content-link').should('be.visible').click()
      cy.get('.delete-content-link').click()
      cy.visit('/').get('#search').type(updated_name + '{enter}', {
        force: true
      }).get('.search-results .grid-item:contains(' + updated_name + ')').should('have.length', 0)
    })
  })
})
