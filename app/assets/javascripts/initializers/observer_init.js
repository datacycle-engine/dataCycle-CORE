import ScheduleEditor from '../components/schedule_editor';

export default function () {
  var schedule_editors = [];

  $('.schedule-editor').each((_i, elem) => {
    schedule_editors.push(new ScheduleEditor($(elem)));
  });

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();
    $(event.target)
      .find('.schedule-editor')
      .addBack('.schedule-editor')
      .each((_i, elem) => {
        schedule_editors.push(new ScheduleEditor($(elem)));
      });
  });
}
