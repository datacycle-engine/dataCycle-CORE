import DataList from './../components/data_list';

export default function () {
  let init = (container = document) => {
    container.querySelectorAll(':scope .ajax-datalist').forEach(item => {
      new DataList(item);
    });
  };

  init();

  $(document).on('dc:html:changed', '*', event => {
    event.stopPropagation();

    init(event.target);
  });
}
