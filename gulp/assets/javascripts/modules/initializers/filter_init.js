// Filter
module.exports.initialize = function () {

  // submit searchform on blur
  if ($('#search-form').length > 0) {
    $('#search-form input#search').change(function () {
      $(this).closest('#search-form').submit();
    });
  }

  if ($('#primary_nav_wrap').length > 0) {
    split_setup();
    setup();
  }

  function split_setup() {
    // Configure Split List
    var num_cols = 4,
      container = $('.split-list'),
      listItem = 'li',
      listClass = 'sub-list';
    container.each(function () {
      var items_per_col = new Array(),
        items = $(this).find(listItem),
        min_items_per_col = Math.floor(items.length / num_cols),
        difference = items.length - (min_items_per_col * num_cols);
      for (var i = 0; i < num_cols; i++) {
        if (i < difference) {
          items_per_col[i] = min_items_per_col + 1;
        } else {
          items_per_col[i] = min_items_per_col;
        }
      }
      for (var i = 0; i < num_cols; i++) {
        $(this).append($('<ul ></ul>').addClass(listClass));
        for (var j = 0; j < items_per_col[i]; j++) {
          var pointer = 0;
          for (var k = 0; k < i; k++) {
            pointer += items_per_col[k];
          }
          $(this).find('.' + listClass).last().append(items[j + pointer]);
        }
      }
    });
  }

  function clearForm(form) {
    $(form).find(':input').not(':button, :submit, :reset, :hidden, :checkbox, :radio').val('');
    $(form).find(':checkbox, :radio').prop('checked', false);
  }

  function setup() {
    // hide activated filters
    if ($('.activefilter').find('.your-choice.tags:visible').length == 0) $('.activefilter').hide();
    // Reset selected Tags
    $('#search-form #reset-filter').on('click', function (e) {
      e.preventDefault();
      var form = $(this).closest('#search-form');
      clearForm(form);
      // $(form).append('<input type="hidden" name="reset" value="true" />');
      form.submit();
    });

    // Save active Filter with specific name
    $('#save-filter-name-form').on('submit', function (e) {
      e.preventDefault();
      var form = $('#search-form');
      $(form).prop('action', $(this).prop('action'));
      $(form).prop('method', $(this).prop('method'));
      $(form).append($(this).find('input[type=hidden]').clone());
      $(form).append('<input type="hidden" name="stored_filter_name" value="' + $(this).find('#stored_filter_name').val() + '">');
      $(form).append('<input type="hidden" name="stored_filter_system" value="' + $(this).find('#stored_filter_system').is(':checked') + '">');
      $(form).append('<input type="hidden" name="stored_filter_api" value="' + $(this).find('#stored_filter_api').is(':checked') + '">');

      form.submit();
    });

    // remove your-choice tags on click
    $(document).on('click', '.filters .your-choice.tags label', function (e) {
      removeFilter($(this));
    });

    $(document).on('click', '.filters .sprache ul label', function (e) {
      $('.filters .your-choice.tags.sprache .tag').text($(this).text());
    });

    $(document).on('click', '.filters .filter ul label', function (e) {
      var id = $(this).attr('for');
      var title = $(this).find('span.inner-title').first().html();
      var tree_label = $(this).parents('.filter').data('tree-label');

      if ($(this).siblings('input[type=checkbox]').first().is(':checked') == true) {
        removeFilter($('.filters .your-choice.tags.' + tree_label).find('label[for=' + id + ']'));
      } else {
        var selected_label = $('.filters .your-choice.tags.' + tree_label).find('[for=' + id + ']');
        if (selected_label.length == 0) {
          var renderedTag = '<label for="' + id + '"><a class="tag">' + title + '<i class="fa fa-times" aria-hidden="true"></i></a> </label>';
          $('.filters .your-choice.tags.' + tree_label).append(renderedTag);
        } else {
          selected_label.show();
        }
        $('.activefilter').show();
        $('.filters .your-choice.tags.' + tree_label).show();
      }
    });

    var category_filter_heights = [];
    $('#primary_nav_wrap ul li').hover(function () {
      category_filter_heights.push($(this).find('ul').height() || 0);
      var height = Math.max.apply(null, category_filter_heights);
      $(this).parentsUntil('#primary_nav_wrap').find('ul:visible').each(function () {
        $(this).css('min-height', height);
      });
    }, function () {
      category_filter_heights.pop();
      var height = Math.max.apply(null, category_filter_heights);
      $(this).parentsUntil('#primary_nav_wrap').find('ul:visible').each(function () {
        $(this).css('min-height', height);
      });
    });
  }

  function removeFilter(elem) {
    if (elem.siblings('label:visible').length == 0) {
      elem.parent().hide();
    }
    elem.hide();
    if ($('.activefilter').find('.your-choice.tags:visible').length == 0) $('.activefilter').hide();
  }

};
