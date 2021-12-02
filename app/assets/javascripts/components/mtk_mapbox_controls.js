class CustomControl {
  constructor(editor) {
    this.editor = editor;
    this.className = '';
    this.title = '';
  }
  onAdd(map) {
    this.map = map;
    this.container = this._createElement();

    return this.container;
  }
  onRemove() {
    this.container.remove();
    this.map = undefined;
    this.editor = undefined;
  }
  _createElement() {
    const container = document.createElement('div');
    container.className = 'mapboxgl-ctrl-group mapboxgl-ctrl';
    const el = document.createElement('button');
    el.className = this.className;
    el.title = this.title;
    el.addEventListener('click', this._clickHandler.bind(this));

    container.appendChild(el);
    return container;
  }
  _clickHandler(event) {
    event.preventDefault();
    event.stopImmediatePropagation();
  }
}

class RemoveWaypointControl extends CustomControl {
  constructor(editor) {
    super(editor);

    this.className = 'dc-mtk-remove-waypoint';
  }
  _clickHandler(event) {
    event.preventDefault();
    event.stopImmediatePropagation();

    this.editor.deleteBox();
  }
}

export { RemoveWaypointControl };
