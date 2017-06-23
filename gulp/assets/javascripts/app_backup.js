  // if ($('form.edit_creative_work').html() != undefined) {
  //   var form = document.querySelector('form.edit_creative_work');

  //   $(form).find('.validation-container').focusout(function () {
  //     var $itemsToValidate = $(this).find('[data-validate]');
  //     if ($itemsToValidate.length > 0) {
  //       var items;

  //       if ($itemsToValidate.first().data('validate') == "text") items = $itemsToValidate;
  //       else if ($itemsToValidate.first().data('validate') == "classification") items = $(this).find('input[type="hidden"]');
  //       else if ($itemsToValidate.first().data('validate') == "daterange") items = $(this).find('input[type="date"]');

  //       validate_single_item(form, items);
  //     }
  //   });
  //   form.onsubmit = function () { return submit_creative_work_form(form); };
  // }

  // // submit searchform on blur
  // if ($('#search-form').length > 0) {
  //   $('#search-form input#search').change(function () {
  //     $(this).closest('#search-form').submit();
  //   });
  // }

  // newApp = new Vue({
  //     el: '#app2',
  //     template: '<App/>',
  //     components: { App },
  // });

  // //todo: make this more fancy
  // //remove your-choice tags on click
  // $(document).on('click', '#primary_nav_wrap .your-choice.tags label', function (e) {
  //   $(this).hide();
  // });

  // //todo: make this more fancy
  // //add tags to your-choice tags on click
  // $(document).on('click', '#primary_nav_wrap li.subtree ul label', function (e) {
  //   var id = $(this).attr('for');
  //   var title = $(this).find('span.inner-title').first().html();
  //   var renderedTag = '<label for="' + id + '"><a class="tag">' + title + '<i class="fa fa-times" aria-hidden="true"></i></a> </label>';
  //   $('#primary_nav_wrap .your-choice.tags').append(renderedTag);

  //   if ($(this).siblings('input[type=checkbox]').first().is(':checked') == true) {
  //     //remove tag
  //     $('#primary_nav_wrap .your-choice.tags').find('label[for=' + id + ']').hide();
  //   } else {
  //     //do nothing
  //   }
  // });


  // //schickt flash callout success nach oben
  // if ($('div.flash.callout').length) {
  //   $("div.flash.callout").parent('div').removeAttr('style');
  //   $('body').prepend($("body").find("div.flash.callout"));
  //   $("div.flash.callout").show();
  //   setTimeout(function () { $("div.flash.callout.success").slideUp("slow"); }, 4000);
  // }

  //fixed hover/focus on daterange
  // $(document).on('click', '.daterange:not(.focus)', function () { $(this).addClass("focus").find('input:first').focus(); });
  // $(".daterange").focusin(function () { $(this).addClass("focus"); });
  // $(".daterange").focusout(function () { $(this).removeClass("focus"); });
  // //fixed hover/focus on form fields
  // $(".form-element:not(.focus)").bind('mousedown click', function (event) {
  //     $(".form-element").removeClass("focus");
  //     $(this).addClass("focus").find('input[type=search]').attr("placeholder", "Hier klicken und Begriffe auswählen.");
  //     event.stopPropagation();
  // });
  // $("body").mousedown(function () { $(".form-element.focus").removeClass("focus") });

  // $('body').on('mousedown', function (ev) {
  //   $('.focus').each(function () {
  //     $(this).removeClass('focus');
  //     $(this).trigger('focusout');
  //   });
  // });
  // $('.validation-container').on('mousedown click focusin', function (ev) {

  //   $('.focus').not(this).each(function () {
  //     $(this).removeClass('focus');
  //     $(this).trigger('focusout');
  //   });
  //   $(this).addClass('focus').find('input[type=search]').attr("placeholder", "Hier klicken und Begriffe auswählen.");
  //   ev.stopPropagation();
  // });



  // //filter 
  // if ($('#primary_nav_wrap').length) {
  //   init_filter();
  // }
  // $('#primary_nav_wrap > ul > li.subtree').hover(function () {
  //   ulminheight = $(this).find('ul').first();
  //   $(this).find('ul').each(function () {
  //     $(this).css('min-height', ulminheight.height());
  //   });
  // });
  // $('#primary_nav_wrap > ul > li.subtree ul li').hover(function () {
  //   ulminheight = $(this).find('ul').first();
  //   $(this).parentsUntil($('#primary_nav_wrap > ul'), 'ul').each(function () {
  //     $(this).css('min-height', ulminheight.height());
  //   });
  // });


  // mediabrowser

  // $('.object-browser').on('click', '.delete-thumbnail', function (ev) {
  //   $(this).parent('.media.thumbnail').remove();
  //   ev.preventDefault();
  // });

  // $('.media-thumbs').on('click', '.mediabrowser', function (ev) {
  //   var media_type = $(this).data('media-type');

  //   var $modal = $('#mediabrowser');
  //   var $media_content = $('#media-content');

  //   $.ajax({
  //     url: '/mediabrowser',
  //     dataType: "json"
  //   })
  //     .done(function (data) {
  //       $modal.foundation('open');
  //       render_media(data, $media_content);

  //       $('#mediabrowser .media').on('click', function (event) {
  //         $(this).toggleClass('add');
  //         if ($(this).is('.add')) {
  //           var $active_item = $(this);
  //           $("#media-info .add-metadata").each(function () {
  //             if ($(this).attr('id') == "thumb-url") $(this).html("<img src='" + $active_item.data($(this).attr('id')) + "'>");
  //             else if ($(this).attr('id') == "media-file-url") $(this).html("<a href='" + $active_item.data($(this).attr('id')) + "' target='_blank'>" + $active_item.data($(this).attr('id')) + "</a>");
  //             else $(this).html($active_item.data($(this).attr('id')));
  //           });
  //         }
  //         else {
  //           $("#media-info .add-metadata").html('');
  //         }
  //         var numItems = $('.media.add').length;
  //         $("#close-media-browser").html("<strong>" + numItems + "</strong> Elemente auswählen");
  //         if (numItems == 1) { $("#close-media-browser").html("<strong>" + numItems + "</strong> Element auswählen"); }
  //         if (numItems == 0) { $("#close-media-browser").html("Keine Elemente auswählen"); }
  //         event.preventDefault();
  //       });

  //       $('#mediabrowser .close-button').on('click', function (ev) {
  //         $('#media-content').html('');
  //         $("#close-media-browser").remove();
  //       });

  //       $('#mediabrowser #close-media-browser').on('click', function (event) {
  //         var $thumbs = $('#creative_work_datahash_image .media-thumbs');
  //         var $addButton = $('#creative_work_datahash_image .media-thumbs button.mediabrowser').prop('outerHTML');
  //         $thumbs.html('');
  //         $('#mediabrowser .add').each(function (index) {
  //           var id = $(this).data('media-id');
  //           var thumbUrl = $(this).data('thumb-url');
  //           var name = $(this).data('media-name');
  //           var html = "<div class='media thumbnail' style='background-image: url(" + thumbUrl + ");'><a class='delete-thumbnail' href='#'><i aria-hidden='true' class='fa fa-times'></i></a><span class='caption'>" + name + "</span><input type='hidden' name='creative_work[datahash][image][]' value='" + id + "' />"
  //           //var html = "<div class='item'><a class='delete-item' href='#'><i aria-hidden='true' class='fa fa-times'></i></a><strong>"+name+"</strong><br /><img src='"+thumbUrl+"' />";
  //           $thumbs.append(html);
  //         });
  //         $thumbs.append($addButton);
  //         $modal.foundation('close');
  //         $('#media-content').html('');
  //         $("#close-media-browser").remove();
  //         event.preventDefault();
  //       });
  //     });

  //   ev.preventDefault();
  // });
  // $('#main-menu button.button').on('click', function (ev) {
  //   $('#mediabrowser').foundation('close');
  //   $('#media-content').html('');
  //   $("#close-media-browser").remove();
  // });


// function formatBytes(a, b) { if (0 == a) return "0 Bytes"; var c = 1e3, d = b || 2, e = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"], f = Math.floor(Math.log(a) / Math.log(c)); return parseFloat((a / Math.pow(c, f)).toFixed(d)) + " " + e[f] }

// function render_media(data, $media_content) {
//   for (var i = 0; i < data.length; i++) {
//     if (data[i].metadata.validation != undefined) {
//       if (data[i].metadata.validation.name == "Bild" && data[i].metadata.thumbnailUrl != undefined) {
//         var name = "";
//         if (data[i].content != null && data[i].content.name != null) name = data[i].content.name;
//         var html = "<a class='media thumbnail'";
//         html += " data-media-id='" + data[i].id + "'";
//         html += " data-media-dimensions='" + data[i].metadata.width + " x " + data[i].metadata.height + "'";
//         html += " data-media-format='" + data[i].metadata.fileFormat + "'";
//         html += " data-media-license='" + data[i].metadata.license + "'";
//         html += " data-media-size='" + formatBytes(data[i].metadata.contentSize) + "'";
//         html += " data-media-file-url='" + data[i].metadata.contentUrl + "'";
//         html += " data-media-date-modified='" + $.date(data[i].metadata.dateCreated) + "'";
//         html += " data-media-date-created='" + $.date(data[i].metadata.dateModified) + "'";
//         html += " data-thumb-url='" + data[i].metadata.thumbnailUrl + "'";
//         html += " data-media-name='" + name + "'";
//         html += " style='background-image: url(" + data[i].metadata.thumbnailUrl + ");'>";
//         html += "<span class='caption'>" + name + "</span></a>"
//         $media_content.append(html);
//       }
//     }
//   }
//   // mark existing ones
//   var numbObjects = $('.object-browser .media-thumbs .media input[type=hidden]').length;
//   var buttonText = "Keine Elemente auswählen";
//   if (numbObjects == 1) buttonText = "1 Element auswählen";
//   else if (numbObjects > 1) buttonText = numbObjects + " Element auswählen";
//   $('.object-browser .media-thumbs .media input[type=hidden]').each(function (index) {
//     var id = $(this).val();
//     $('a[data-media-id=' + id + ']').addClass('add');
//   });
//   $("#mediabrowser h4").append("<button data-close type='button' class='button' id='close-media-browser' style='display: block;'><span aria-hidden='true'>" + buttonText + "</span></button>");
// }

// function init_masonry() {
//   if ($('.grid').html() != undefined) {
//     var grid = new masonry('.grid', {
//       // var $grid = $('.grid').masonry({
//       // options
//       // set itemSelector so .grid-sizer is not used in layout
//       itemSelector: '.grid-item',
//       // use element for option
//       columnWidth: '.grid-sizer',
//       gutter: '.gutter-sizer',
//       percentPosition: true
//     });
//     $('.grid .grid-loading').removeClass("show");
//     $.each($('.grid-item'), function (i, el) {
//       setTimeout(function () {
//         $(el).addClass("show");
//       }, 50 + (i * 20));
//     });

//   }
// }


// // QuillJS Word Counter Module
// var Counter = function (quill, options) {
//   this.quill = quill;
//   this.options = options;
//   this.limit = parseInt(this.options.limit) || 0;
//   this.unit = this.options.unit || "zeichen";
//   this.container = this.setContainer();
//   quill.on('text-change', this.update.bind(this));
//   this.update();
// };

// Counter.prototype.setContainer = function () {
//   var parentElement = this.quill.container.parentElement;
//   if (parentElement.querySelector('#counter') == null) parentElement.insertAdjacentHTML('beforeend', '<div id="counter"></div>');
//   return parentElement.querySelector('#counter');
// };
// Counter.prototype.countWords = function (text) {
//   return text.trim().length > 0 ? text.trim().split(/\s+/).length : 0;
// };
// Counter.prototype.countChars = function (text) {
//   return text.length - 1 > 0 ? text.length - 1 : 0;
// };

// Counter.prototype.calculate = function () {
//   var text = this.quill.getText();
//   var length, length_words, length_chars = 0;

//   if (this.options.unit === "wörter") length = this.countWords(text);
//   else if (this.options.unit === "zeichen") length = this.countChars(text);

//   if (this.limit > 0 && length > this.limit) this.quill.deleteText(this.quill.getLength() - 2, 1);

//   text = this.quill.getText();

//   return { words: this.countWords(text), chars: this.countChars(text) };
// };

// Counter.prototype.update = function () {
//   var length = this.calculate();
//   var chars = length.chars;
//   var words = length.words;
//   var limit_label = this.options.unit;
//   if (this.options.unit === "wörter") limit_label = this.limit == 1 ? "Wort" : "Wörter";
//   else if (this.options.unit === "zeichen") limit_label = "Zeichen";
//   var char_label = "Zeichen";
//   var word_label = words == 1 ? "Wort" : "Wörter";

//   this.container.innerHTML = words + ' ' + word_label + ' / ' + chars + ' ' + char_label;
// };

// quill.register('modules/counter', Counter);



// function init_feeditor(node) {
//   var Delta = quill.import('delta');

//   // set edit mode
//   var mode = "full";
//   if ($(node).data('size') != undefined && $(node).data('size') != false) mode = $(node).data('size');
//   else if ($(node).attr('size') != undefined && $(node).attr('size') != false) mode = $(node).attr('size');

//   var formats = {
//     "none": [],
//     "basic": ['bold', 'italic', 'header', 'underline'],
//     "full": ['bold', 'italic', 'header', 'underline', 'link', 'list', 'align']
//   };

//   var toolbar = {
//     "none": [],
//     "basic": [[{ header: [1, 2, 3, false] }],
//     ['bold', 'italic', 'underline']],
//     "full": [[{ 'align': [] }],
//     [{ 'list': 'ordered' }, { 'list': 'bullet' }],
//     [{ header: [1, 2, 3, false] }],
//     ['bold', 'italic', 'underline'],
//     ['link']]
//   };

//   var options = {
//     modules: {
//       counter: {
//         unit: 'zeichen'
//       },
//       toolbar: toolbar[mode]
//     },
//     theme: 'snow',  // or 'bubble'
//     formats: formats[mode]
//   };

//   var editor = new quill('#' + node.id, options);
// }


// //FILTER DROPDOWN FUNCTIONS
// function init_filter() {

//   //split list
//   var num_cols = 4,
//     container = $('.split-list'),
//     listItem = 'li',
//     listClass = 'sub-list';
//   container.each(function () {
//     var items_per_col = new Array(),
//       items = $(this).find(listItem),
//       min_items_per_col = Math.floor(items.length / num_cols),
//       difference = items.length - (min_items_per_col * num_cols);
//     for (var i = 0; i < num_cols; i++) {
//       if (i < difference) {
//         items_per_col[i] = min_items_per_col + 1;
//       } else {
//         items_per_col[i] = min_items_per_col;
//       }
//     }
//     for (var i = 0; i < num_cols; i++) {
//       $(this).append($('<ul ></ul>').addClass(listClass));
//       for (var j = 0; j < items_per_col[i]; j++) {
//         var pointer = 0;
//         for (var k = 0; k < i; k++) {
//           pointer += items_per_col[k];
//         }
//         $(this).find('.' + listClass).last().append(items[j + pointer]);
//       }
//     }
//   });
//   //split list

// };
// //END FILTER DROPDOWN FUNCTIONS


// function submit_creative_work_form(form) {
//   //get quill-js values
//   if ($('.quill-editor').html() != undefined) {
//     $('.quill-editor').each(function () {
//       set_fe_editor_values(this)
//     });
//   }

//   var isValid = validate_complete_form(form);

//   if (isValid == true) {
//     form.submit();
//   } else {
//     return false;
//   }

// }

// function set_fe_editor_values(editor) {
//   var hidden_field_id = $(editor).attr('data-hidden-field-id');
//   var hidden_field = document.querySelector('input#' + hidden_field_id);
//   hidden_field.value = $(editor).find('.ql-editor').html();
// }

// function validate_complete_form(form) {

//   $('#validation_errors').html('');

//   var isValid = true;

//   $(form).find('.validation-container').each(function () {
//     var $itemsToValidate = $(this).find('[data-validate]');
//     if ($itemsToValidate.length > 0) {
//       var items;

//       if ($itemsToValidate.first().data('validate') == "text") items = $itemsToValidate;
//       else if ($itemsToValidate.first().data('validate') == "classification") items = $(this).find('input[type="hidden"]');
//       else if ($itemsToValidate.first().data('validate') == "daterange") items = $(this).find('input[type="date"]');

//       if (validate_single_item(form, items) == false) isValid = false;
//     }
//   });
//   return isValid;
// }

// function validate_single_item(form, item) {

//   //reset errors
//   $(item).closest('.validation-container').find('.single_error').remove();
//   $(item).closest('.validation-container').removeClass('has-error');

//   var uuid = $(form).find('input#uuid').val();
//   var validation_url = /validatetest/;
//   var url = validation_url + uuid;

//   var formdata = $(item).serializeArray();

//   is_creative_work = new RegExp('^' + 'creative_work', 'i');

//   isValid = true;

//   if (is_creative_work.test(formdata[0].name)) {

//     $.ajax({
//       type: "POST",
//       url: url,
//       data: $.param(formdata), // serializes the form's elements.
//       async: false,
//       success: function (data) {
//         if (data.error.length > 0) {
//           $(item).closest('.validation-container').append(render_error_msg(data, item));
//           $(item).closest('.validation-container').addClass('has-error');
//           isValid = false;
//         }
//       }
//     });
//   }

//   return isValid;

// }

// function render_error_msg(data, item) {
//   var out = '';
//   var item_id = '';
//   if (item != null && $(item).attr('id') != undefined) item_id = "id='" + $(item).attr('id') + "_error'";
//   else if (item != null && $(item).closest('.form-element').find('label').first().attr('for') != undefined) item_id = "id='" + $(item).closest('.form-element').find('label').first().attr('for') + "_error'";

//   item_label = (item != null) ? $(item).closest('.form-element').find('label').first().html() + ": " : "";
//   $.each(data.error, function (key, val) {
//     out += "<span " + item_id + "class='single_error'><strong>" + item_label + "</strong>" + val + "</span>";
//   });
//   return out;
// }

// // realign masonry after all images are loaded
// var chkReadyState = setInterval(function () {

//   if ($('.grid').html() != undefined) {
//     $('.grid .grid-loading').addClass("show");
//   }

//   if (document.readyState == "complete") {

//     clearInterval(chkReadyState);
//     init_masonry();
//     // finally your page is loaded.
//   }
// }, 100);
