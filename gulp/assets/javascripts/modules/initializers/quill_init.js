var quill = require('quill');
var Counter = require('./../components/quill_counter');

// Quill Config
module.exports.initialize = function () {

  quill.register('modules/counter', Counter);

  $(document).on('clone-added', '.content-object-item', function () {

    if ($(this).find('.quill-editor').html() != undefined) {
      $(this).find('.quill-editor').each(function () {
        init(this);
      });
    }
  });

  if ($('.quill-editor').html() != undefined) {
    $('.quill-editor').each(function () {
      init(this);
    });
  }

  function init(node) {
    var Delta = quill.import('delta');

    // set edit mode
    var mode = "full";
    if ($(node).data('size') != undefined && $(node).data('size') != false) mode = $(node).data('size');
    else if ($(node).attr('size') != undefined && $(node).attr('size') != false) mode = $(node).attr('size');

    var formats = {
      "none": [],
      "basic": ['bold', 'italic', 'header', 'underline'],
      "full": ['bold', 'italic', 'header', 'underline', 'link', 'list', 'align']
    };

    var toolbar = {
      "none": [],
      "basic": [
        [{
          header: [1, 2, 3, false]
        }],
        ['bold', 'italic', 'underline']
      ],
      "full": [
        [{
          'align': []
        }],
        [{
          'list': 'ordered'
        }, {
          'list': 'bullet'
        }],
        [{
          header: [1, 2, 3, false]
        }],
        ['bold', 'italic', 'underline'],
        ['link']
      ]
    };

    var max = $(node).parent().data('max');

    var readonly = $(node).attr('readonly') ? true : false;

    var options = {
      modules: {
        counter: {
          unit: 'zeichen',
          max: max
        },
        toolbar: toolbar[mode]
      },
      theme: 'snow', // or 'bubble'
      formats: formats[mode],
      readOnly: readonly
    };

    var editor = new quill('#' + node.id, options);
  }

  $(window).on('scroll', function (ev) {
    $('.editor-block').each(function () {
      var pos = $(this).offset().top - $(window).scrollTop();
      if (pos < 55 && pos > -$(this).height() + 130) {
        $(this).find('.ql-toolbar').addClass('fixed-toolbar');
        $(this).siblings('label').addClass('fixed-toolbar');
      } else {
        $(this).find('.ql-toolbar').removeClass('fixed-toolbar');
        $(this).siblings('label').removeClass('fixed-toolbar');
      }
    });
  });

};
