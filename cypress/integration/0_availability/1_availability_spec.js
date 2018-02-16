// describe('Availability', function () {
//   beforeEach(function () {
//     cy.login('admin')
//   })

//   it('info', function () {
//     cy.request({
//       url: '/info',
//       followRedirect: false
//     }).then((response) => {
//       expect(response.status).to.eq(200)
//     })
//   })

//   it('backend', function () {
//     cy.request({
//       url: '/',
//       followRedirect: false
//     }).then((response) => {
//       expect(response.status).to.eq(200)
//     })
//   })

//   it('settings', function () {
//     cy.request({
//       url: '/settings',
//       followRedirect: false
//     }).then((response) => {
//       expect(response.status).to.eq(200)
//     })
//   })

//   it('users', function () {
//     cy.request({
//       url: '/users',
//       followRedirect: false
//     }).then((response) => {
//       expect(response.status).to.eq(200)
//     })
//   })

//   it('user groups', function () {
//     cy.request({
//       url: '/user_groups',
//       followRedirect: false
//     }).then((response) => {
//       expect(response.status).to.eq(200)
//     })
//   })

//   it('subscriptions', function () {
//     cy.request({
//       url: '/subscriptions',
//       followRedirect: false
//     }).then((response) => {
//       expect(response.status).to.eq(200)
//     })
//   })

//   it('watchlists', function () {
//     cy.request({
//       url: '/watch_lists',
//       followRedirect: false
//     }).then((response) => {
//       expect(response.status).to.eq(200)
//     })
//   })

//   it('classifications', function () {
//     cy.request({
//       url: '/classifications',
//       followRedirect: false
//     }).then((response) => {
//       expect(response.status).to.eq(200)
//     })
//   })
// })
