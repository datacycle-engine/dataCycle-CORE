export default function () {
  const manualDuplicates = document.querySelector('.manual-duplicates');

  if (!manualDuplicates) return;

  const form = manualDuplicates.querySelector('form');
  const objectBrowser = manualDuplicates.querySelector('.object-browser');

  $(objectBrowser).on('dc:objectBrowser:change', (event, data) => {
    event.preventDefault();
    event.stopPropagation();

    if (data.ids && data.ids.length) {
      $(window).off('beforeunload');
      form.submit();
    } else console.warn('no ids given for manual duplicate_candidate');
  });
}
