import ImageEditor from '../components/image_editor';

export default function () {
  for (const element of document.querySelectorAll('.image-editor-reveal.dcjs-foundation-reveal'))
    new ImageEditor(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e =>
      e.classList.contains('image-editor-reveal') &&
      e.classList.contains('dcjs-foundation-reveal') &&
      !e.classList.contains('dcjs-image-editor'),
    e => new ImageEditor(e)
  ]);
}
