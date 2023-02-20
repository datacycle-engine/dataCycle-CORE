export default function () {
  $('.close-admin-panel').on('click', event => {
    event.preventDefault();

    $(event.currentTarget).closest('section#admin-panel').find('ul#admin-icons ').foundation('_collapse');
  });
}
