// FIXME: fix as soon, as select2 stops using AMD
export default {
  errorLoading: () => {
    return 'Die Ergebnisse konnten nicht geladen werden.';
  },
  inputTooLong: args => {
    var overChars = args.input.length - args.maximum;

    return 'Bitte ' + overChars + ' Zeichen weniger eingeben';
  },
  inputTooShort: args => {
    var remainingChars = args.minimum - args.input.length;

    return 'Bitte ' + remainingChars + ' Zeichen mehr eingeben';
  },
  loadingMore: () => {
    return 'Lade mehr Ergebnisse…';
  },
  maximumSelected: args => {
    var message = 'Sie können nur ' + args.maximum + ' Element';

    if (args.maximum != 1) {
      message += 'e';
    }

    message += ' auswählen';

    return message;
  },
  noResults: () => {
    return 'Keine Übereinstimmungen gefunden';
  },
  searching: () => {
    return 'Suche…';
  },
  removeAllItems: () => {
    return 'Entferne alle Elemente';
  }
};
