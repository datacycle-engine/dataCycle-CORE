// FIXME: fix as soon, as select2 stops using AMD
export default {
  errorLoading: () => {
    return 'The results could not be loaded.';
  },
  inputTooLong: args => {
    var overChars = args.input.length - args.maximum;

    var message = 'Please delete ' + overChars + ' character';

    if (overChars != 1) {
      message += 's';
    }

    return message;
  },
  inputTooShort: args => {
    var remainingChars = args.minimum - args.input.length;

    var message = 'Please enter ' + remainingChars + ' or more characters';

    return message;
  },
  loadingMore: () => {
    return 'Loading more results…';
  },
  maximumSelected: args => {
    var message = 'You can only select ' + args.maximum + ' item';

    if (args.maximum != 1) {
      message += 's';
    }

    return message;
  },
  noResults: () => {
    return 'No results found';
  },
  searching: () => {
    return 'Searching…';
  },
  removeAllItems: () => {
    return 'Remove all items';
  }
};
