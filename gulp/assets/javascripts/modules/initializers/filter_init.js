// Filter
module.exports.initialize = function () {

  let remove_filter = function (elem) {
    if (elem.siblings('label:visible').length == 0) {
      elem.parents('.tag-group').hide();
    }
    elem.hide();
    if ($('.activefilter').find('.tag-group.tags:visible').length == 0) $('.activefilter').hide();
  }

  let split_setup = function () {
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

  let setup = function () {
    // remove tag-group tags on click
    $(document).on('click', '.filters .tag-group.tags:not(.advanced-tags) label', function (e) {
      remove_filter($(this));
    });

    $(document).on('click', '.filters .sprache ul label', function (e) {
      $('.filters .tag-group.tags.sprache .tag').text($(this).text());
    });

    $(document).on('click', '.filters .filter ul label', function (e) {
      var id = $(this).attr('for');
      var title = $(this).find('span.inner-title').first().html();
      var tree_label = $(this).parents('.filter').data('tree-label');
      var tree_label_title = $(this).parents('.filter').find('>.title').text();

      if ($(this).siblings('input[type=checkbox]').first().is(':checked')) {
        remove_filter($('.filters .tag-group.tags:not(.advanced-tags).' + tree_label).find('label[for=' + id + ']'));
      } else {
        if (!$('.filters .tag-group.tags:not(.advanced-tags).' + tree_label).length) {
          $('.filters .filtertags .filter-groups').append('<span class="tag-group tags ' + tree_label + '"><i class="tag-group-label"><i class="fa fa-tags" aria-hidden="true"></i> ' + tree_label_title + ':</i> <span class="tags-container"></span></span>');
        }

        var selected_label = $('.filters .tag-group.tags.' + tree_label).find('[for=' + id + ']');
        if (selected_label.length == 0) {
          var renderedTag = '<label for="' + id + '"><a class="tag">' + title + '<i class="fa fa-times" aria-hidden="true"></i></a> </label>';
          $('.filters .tag-group.tags:not(.advanced-tags).' + tree_label + ' .tags-container').append(renderedTag);
        } else {
          selected_label.show();
        }
        $('.activefilter').show();
        $('.filters .tag-group.tags.' + tree_label).show();
      }
    });

    var category_filter_heights = [];
    $('#primary_nav_wrap .clickable-menu').on('mouseenter', 'li.active, li.active li', event => {
      var child_list = $(event.currentTarget).find('ul').first();
      if (child_list.length && Math.round($('.off-canvas-wrapper').outerHeight()) < Math.round(child_list.outerHeight() + child_list.offset().top + 150)) {
        $('.off-canvas-wrapper').css('height', child_list.outerHeight() + child_list.offset().top + 150);
      }

      category_filter_heights.push($(event.currentTarget).find('ul').height() || 0);
      var height = Math.max.apply(null, category_filter_heights);
      $(event.currentTarget).parentsUntil('#primary_nav_wrap').find('ul:visible').each((index, elem) => {
        $(elem).css('min-height', height);
      });
    });
    $('.clickable-menu').on('mouseleave', 'li.active, li.active li', event => {
      category_filter_heights.pop();
      var height = Math.max.apply(null, category_filter_heights);
      $(event.currentTarget).parentsUntil('#primary_nav_wrap').find('ul:visible').each((index, elem) => {
        $(elem).css('min-height', height);
      });
    });

    $('.filters .advanced-filters').on('change', ' .advanced-filter', event => {
      $.ajax({
        url: '/add_tag_group',
        method: 'GET',
        data: {
          t: $(event.currentTarget).find(':input[name*="[t]"]').first().val(),
          n: $(event.currentTarget).find(':input[name*="[n]"]').first().val(),
          v: $(event.currentTarget).find(':input[name*="[v]"]').first().map((index, element) => $(element).val()).get(),
          index: $(event.currentTarget).data('index')
        },
        dataType: 'script',
        contentType: 'application/json'
      });
    });

    $('.filters .advanced-filters #add_advanced_filter').on('change', event => {
      event.preventDefault();
      $(event.currentTarget).prop('disabled', true);
      $.ajax({
        url: $(event.currentTarget).data('url'),
        method: 'GET',
        data: {
          t: $(event.currentTarget).val(),
          n: $(event.currentTarget).find(':selected').data('name'),
          m: $(event.currentTarget).data('method'),
          index: $(event.currentTarget).data('index')
        },
        dataType: 'script',
        contentType: 'application/json'
      }).always(() => {
        $(event.currentTarget).prop('disabled', false);
      });
      $(event.currentTarget).val('');
    });

    $('.filters .advanced-filters, .filters').on('click', '.remove-advanced-filter', event => {
      event.preventDefault();
      $('.advanced-filter[data-id="' + $(event.currentTarget).data('target') + '"], .filters .tag-group[data-id="' + $(event.currentTarget).data('target') + '"]').remove();
    });

    $('.filters .advanced-filters, .filters').on('click', '.focus-advanced-filter', event => {
      event.preventDefault();
      $('.advanced-filter[data-id="' + $(event.currentTarget).data('target') + '"]').addClass('highlight').get(0).scrollIntoView({
        behavior: "smooth"
      });
      setTimeout(() => {
        $('.advanced-filter[data-id="' + $(event.currentTarget).data('target') + '"]').removeClass('highlight');
      }, 1000);
    });
  }

  // submit searchform on blur
  if ($('#search-form').length > 0) {
    $('#search-form input.fulltext-search-field').change(function () {
      $(this).closest('#search-form').submit();
    });
  }

  if ($('#primary_nav_wrap').length > 0) {
    split_setup();
    setup();
  }


  // clickable menu setup
  if ($('.clickable-menu').length) {
    $('.clickable-menu').on('click', '>li', event => {
      if ($(event.currentTarget).hasClass('active') && !$(event.target).parentsUntil('.clickable-menu').filter('ul').length) {
        $(event.currentTarget).trigger('mouseleave');
      } else if (!$(event.currentTarget).hasClass('active')) {
        $('.clickable-menu .active').removeClass('active');
        $(event.currentTarget).addClass('active').trigger('mouseenter');
      }
    });

    $('.clickable-menu').on('mouseleave', '>li.active', event => {
      $(event.currentTarget).removeClass('active');
    });

    $('.clickable-menu input').on('click', event => {
      event.stopPropagation();
    });
  }
};
