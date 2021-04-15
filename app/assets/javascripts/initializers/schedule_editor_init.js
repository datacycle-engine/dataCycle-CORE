import ScheduleEditor from '~/javascripts/components/schedule_editor';

// Word Counter
export default function () {
  var schedule_editors = [];

  $('.schedule-editor').each((i, elem) => {
    schedule_editors.push(new ScheduleEditor($(elem)));
  });

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    $(event.target)
      .find('.schedule-editor')
      .addBack('.schedule-editor')
      .each((i, elem) => {
        schedule_editors.push(new ScheduleEditor($(elem)));
      });
  });
}
