export default {
  errorLoading: () => 'Die Ergebnisse konnten nicht geladen werden.',
  inputTooLong: e => 'Bitte ' + (e.input.length - e.maximum) + ' Zeichen weniger eingeben',
  inputTooShort: e => 'Bitte ' + (e.minimum - e.input.length) + ' Zeichen mehr eingeben',
  loadingMore: () => 'Lade mehr Ergebnisse…',
  maximumSelected: e => {
    var n = 'Sie können nur ' + e.maximum + ' Element';
    return 1 != e.maximum && (n += 'e'), (n += ' auswählen');
  },
  noResults: () => 'Keine Übereinstimmungen gefunden',
  searching: () => 'Suche…',
  removeAllItems: () => 'Entferne alle Elemente'
};
