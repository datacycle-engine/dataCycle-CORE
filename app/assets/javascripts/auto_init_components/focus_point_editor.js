import ImageDetailEditorBase from '../components/image_detail_editor_base';
import debounce from 'lodash/debounce';
import { parseDataAttribute } from '../helpers/dom_element_helpers';
import { showCallout } from '../helpers/callout_helpers';

export default class FocusPointEditor extends ImageDetailEditorBase {
  static selector = '.change-focus-point-ui';
  static className = 'dcjs-focus-point-editor';
  static lazy = true;
  static containerClassName = 'focus-point-ui';
  static i18nNameSpace = 'focus_point_editor';

  constructor(button) {
    super(button);

    this.fp = {
      x: parseDataAttribute(this.button.dataset.focusPointX) || 0.5,
      y: parseDataAttribute(this.button.dataset.focusPointY) || 0.5
    };
    this.thingId = this.button.dataset.thingId;
    this.fpXKey = this.button.dataset.focusPointXKey;
    this.fpYKey = this.button.dataset.focusPointYKey;
    this.sendFocusPointFunction = debounce(this.sendFocusPoint.bind(this), 200);

    this.handlers = {
      updatePosition: this.updatePosition.bind(this),
      overlayStartMove: this.overlayStartMove.bind(this),
      overlayStopMove: this.overlayStopMove.bind(this),
      clearFocusPoint: this.clearFocusPoint.bind(this)
    };
  }

  insertFocusPointUi() {
    this.imageContainer.insertAdjacentHTML(
      'beforeend',
      `<div class="focus-point-ui">
        <div class="focus-point-ui__overlay"></div>
        <div class="focus-point-ui__crosshair"></div>
      </div>`
    );

    this.button.insertAdjacentHTML(
      'afterend',
      `<button class="button alert hollow focus-point-clear" data-dc-tooltip>
        <i class="fa fa-times"></i>
      </button>`
    );
    this.clearButton = this.button.nextElementSibling;

    I18n.t('feature.focus_point_editor.clear_focus_point').then(text => {
      this.clearButton.dataset.dcTooltip = text;
    });

    this.focusPointUi = this.imageContainer.querySelector('.focus-point-ui');
    this.crossHair = this.focusPointUi.querySelector('.focus-point-ui__crosshair');
    this.overlay = this.focusPointUi.querySelector('.focus-point-ui__overlay');
  }

  async enableEditing() {
    await super.enableEditing();

    this.insertFocusPointUi();
    this.initOverlayPosition();

    this.focusPointUi.addEventListener('click', this.handlers.updatePosition);
    this.focusPointUi.addEventListener('mousedown', this.handlers.overlayStartMove);
    addEventListener('mouseup', this.handlers.overlayStopMove);
    this.clearButton.addEventListener('click', this.handlers.clearFocusPoint);
  }

  async disableEditing() {
    await super.disableEditing();

    if (this.focusPointUi) {
      this.focusPointUi.removeEventListener('click', this.handlers.updatePosition);
      this.focusPointUi.removeEventListener('mousedown', this.handlers.overlayStartMove);
      removeEventListener('mouseup', this.handlers.overlayStopMove);

      this.focusPointUi.remove();
      this.clearButton.remove();
    }
  }

  overlayStartMove(event) {
    event.preventDefault();

    this.updateOverlayPosition(event.clientX, event.clientY);

    addEventListener('mousemove', this.handlers.updatePosition);
  }

  roundFocusPoint(value) {
    return Math.round(value * 100) / 100;
  }

  overlayStopMove(event) {
    event.preventDefault();

    removeEventListener('mousemove', this.handlers.updatePosition);
  }

  updatePosition(event) {
    event.preventDefault();

    this.updateOverlayPosition(event.clientX, event.clientY);
  }

  setOverlayPosition(olPosition) {
    this.focusPointUi.style.setProperty('--focus-point-ui-overlay-left', `${olPosition.left}px`);
    this.focusPointUi.style.setProperty('--focus-point-ui-overlay-top', `${olPosition.top}px`);
  }

  setCrossHairPosition(chPosition) {
    this.focusPointUi.style.setProperty('--focus-point-ui-crosshair-left', `${chPosition.left}px`);
    this.focusPointUi.style.setProperty('--focus-point-ui-crosshair-top', `${chPosition.top}px`);
  }

  initOverlayPosition() {
    if (!this.focusPointUi || !this.fp) return;

    const fpRect = this.focusPointUi.getBoundingClientRect();
    const x = this.fp.x * fpRect.width;
    const y = this.fp.y * fpRect.height;
    const olPosition = this.calculateOverlayPosition(x, y, fpRect);
    const chPosition = this.calculateCrossHairPosition(x, y, fpRect);

    if (olPosition) this.setOverlayPosition(olPosition);
    if (chPosition) this.setCrossHairPosition(chPosition);
  }

  updateOverlayPosition(absoluteX, absoluteY) {
    if (!this.focusPointUi) return;

    const focusPointUiRect = this.focusPointUi.getBoundingClientRect();
    const x = absoluteX - focusPointUiRect.x;
    const y = absoluteY - focusPointUiRect.y;

    const olPosition = this.calculateOverlayPosition(x, y, focusPointUiRect);
    const chPosition = this.calculateCrossHairPosition(x, y, focusPointUiRect);
    const fp = this.calculateFocusPoint(x, y, focusPointUiRect);

    if (olPosition) this.setOverlayPosition(olPosition);
    if (chPosition) this.setCrossHairPosition(chPosition);
    if (fp) this.updateFocusPoint(fp);
  }

  updateFocusPoint(fp) {
    if (this.fp.x === fp.x && this.fp.y === fp.y) return;

    this.fp = fp;

    this.sendFocusPointFunction();
  }

  clearFocusPoint(event) {
    event.preventDefault();

    this.fp = { x: 0.5, y: 0.5 };
    this.initOverlayPosition();
    this.sendFocusPointFunction();
  }

  sendFocusPoint() {
    DataCycle.httpRequest(`/things/${this.thingId}/update_focus_point`, {
      method: 'PATCH',
      body: {
        focus_point: {
          [this.fpXKey]: this.fp.x,
          [this.fpYKey]: this.fp.y
        }
      }
    })
      .then(data => {
        if (data.error) showCallout(data.error, 'error');
        else if (data.message) showCallout(data.message, 'success');
      })
      .catch(_error => {
        I18n.t('feature.focus_point_editor.update_error').then(text => {
          showCallout(text, 'error');
        });
      });
  }

  calculateOverlayPosition(x, y, fpRect) {
    const overlayRect = this.overlay.getBoundingClientRect();

    let overlayLeft = x - overlayRect.width / 2;
    if (overlayLeft < 0) overlayLeft = 0;
    else if (overlayLeft + overlayRect.width > fpRect.width) overlayLeft = fpRect.width - overlayRect.width;

    let overlayTop = y - overlayRect.height / 2;
    if (overlayTop < 0) overlayTop = 0;
    else if (overlayTop + overlayRect.height > fpRect.height) overlayTop = fpRect.height - overlayRect.height;

    return {
      left: overlayLeft,
      top: overlayTop
    };
  }

  calculateCrossHairPosition(x, y, fpRect) {
    const chRect = this.crossHair.getBoundingClientRect();

    let crossHairLeft = x - chRect.width / 2;
    if (crossHairLeft < 0) crossHairLeft = 0;
    else if (crossHairLeft + chRect.width > fpRect.width) crossHairLeft = fpRect.width - chRect.width;

    let crossHairTop = y - chRect.height / 2;
    if (crossHairTop < 0) crossHairTop = 0;
    else if (crossHairTop + chRect.height > fpRect.height) crossHairTop = fpRect.height - chRect.height;

    return {
      left: crossHairLeft,
      top: crossHairTop
    };
  }

  calculateFocusPoint(x, y, fpRect) {
    return {
      x: this.roundFocusPoint(x / fpRect.width),
      y: this.roundFocusPoint(y / fpRect.height)
    };
  }
}
