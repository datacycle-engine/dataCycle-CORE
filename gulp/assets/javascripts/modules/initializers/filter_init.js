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

  function setup() {
    // Reset selected Tags
    $(document).on('click', '#reset-filter', function () {
      $('#primary_nav_wrap .your-choice.tags label').remove();
    });

    // remove your-choice tags on click
    $(document).on('click', '#primary_nav_wrap .your-choice.tags label', function (e) {
      $(this).hide();
    });

    //todo: make this more fancy
    //add tags to your-choice tags on click
    $(document).on('click', '#primary_nav_wrap li.subtree ul label', function (e) {
      var id = $(this).attr('for');
      var title = $(this).find('span.inner-title').first().html();
      var renderedTag = '<label for="' + id + '"><a class="tag">' + title + '<i class="fa fa-times" aria-hidden="true"></i></a> </label>';
      $('#primary_nav_wrap .your-choice.tags').append(renderedTag);

      if ($(this).siblings('input[type=checkbox]').first().is(':checked') == true) {
        //remove tag
        $('#primary_nav_wrap .your-choice.tags').find('label[for=' + id + ']').hide();
      } else {
        //do nothing
      }
    });

    $('#primary_nav_wrap > ul > li.subtree').hover(function () {
      ulminheight = $(this).find('ul').first();
      $(this).find('ul').each(function () {
        $(this).css('min-height', ulminheight.height());
      });
    });
    $('#primary_nav_wrap > ul > li.subtree ul li').hover(function () {
      ulminheight = $(this).find('ul').first();
      $(this).parentsUntil($('#primary_nav_wrap > ul'), 'ul').each(function () {
        $(this).css('min-height', ulminheight.height());
      });
    });
  }

};