import ImageEditor from '../components/image_editor';

export default function () {
  DataCycle.initNewElements(
    '.image-editor-reveal.dcjs-foundation-reveal:not(.dcjs-image-editor)',
    e => new ImageEditor(e)
  );
}
