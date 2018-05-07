// Select2 Helpermethods
module.exports = {
  markMatch: function (text, term) {
    // Find where the match is
    var match = text.toUpperCase().lastIndexOf(term.toUpperCase());

    var $result = $('<span></span>');

    // If there is no match, move on
    if (match < 0) {
      return $result.text(text);
    }

    // Put in whatever text is before the match
    $result.text(text.substring(0, match));

    // Mark the match
    var $match = $('<span class="select2-highlight"></span>');
    $match.text(text.substring(match, match + term.length));

    // Append the matching text
    $result.append($match);

    // Put in whatever is after the match
    $result.append(text.substring(match + term.length));

    return $result;
  },
  decorateResult: function (result) {
    $(result).html(function (index, value) {
      if (value != undefined) {
        var text = value.split(' &gt; ');
        text[text.length - 1] = '<span class="select2-option-title">' + text[text.length - 1] + '</span>';
        return text.join(' > ');
      }
    });
  },
  removeTreeLabel: function (result, treelabel) {
    $(result).html((index, value) => {
      if (value != undefined) {
        return value.replace(treelabel + ' &gt; ', '');
      }
    });
  }
};
