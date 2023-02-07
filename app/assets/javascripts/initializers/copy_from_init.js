import CopyFromAttribute from './../components/copy_from_attribute';

export default function () {
  DataCycle.initNewElements(
    '.copy-from-attribute-feature:not(.dcjs-copy-from-attribute)',
    e => new CopyFromAttribute(e)
  );
}
