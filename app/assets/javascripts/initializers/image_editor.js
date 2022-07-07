import ImageEditor from '../components/image_editor';

export default function () {
  for (const element of document.querySelectorAll('.image-editor-reveal.dc-fd-reveal')) new ImageEditor(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('image-editor-reveal') && e.classList.contains('dc-fd-reveal'),
    e => new ImageEditor(e)
  ]);
}
