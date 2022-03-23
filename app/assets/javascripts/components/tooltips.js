import { computePosition, autoPlacement, autoUpdate, arrow, offset, hide } from '@floating-ui/dom';
import domElementHelpers from '../helpers/dom_element_helpers';

class Tooltips {
  constructor() {
    this.tooltip = document.getElementById('dc-tooltip');
    this.referenceElement;
    this.cleanups = {};
    this.dataChangedObserver = new MutationObserver(this.updateTooltipContent.bind(this));

    this.init();
  }
  init() {
    if (!this.tooltip) this.createTooltip();

    this.initialTooltips();
    this.initNewTooltips();
  }
  createTooltip() {
    const tooltip = document.createElement('div');
    tooltip.id = 'dc-tooltip';

    const arrow = document.createElement('div');
    arrow.id = 'dc-tooltip-arrow';
    tooltip.appendChild(arrow);

    const tooltipContent = document.createElement('div');
    tooltipContent.id = 'dc-tooltip-content';
    tooltip.appendChild(tooltipContent);

    document.body.appendChild(tooltip);

    this.tooltipArrow = arrow;
    this.tooltipContent = tooltipContent;
    this.tooltip = tooltip;
  }
  initialTooltips() {
    const tooltips = document.querySelectorAll('[data-dc-tooltip]');

    for (const tooltip of tooltips) this.addEventsForTooltip(tooltip);
  }
  initNewTooltips() {
    DataCycle.htmlObserver.addCallbacks.push([
      e => e.dataset.dcTooltip && !e.dataset.dcTooltipId,
      this.addEventsForTooltip.bind(this)
    ]);
  }
  addEventsForTooltip(tooltip) {
    tooltip.dataset.dcTooltipId = domElementHelpers.randomId();

    tooltip.addEventListener('mouseenter', this.showTooltipDelayed.bind(this));
    tooltip.addEventListener('mouseleave', this.hideTooltip.bind(this));
  }
  addAutoUpdate() {
    return autoUpdate(this.referenceElement, this.tooltip, this.updatePosition.bind(this), {
      ancestorScroll: false,
      ancestorResize: false,
      elementResize: true
    });
  }
  showTooltipDelayed(event) {
    if (!event.target.dataset.dcTooltip) return;

    this.referenceElement = event.target;

    setTimeout(this.showTooltip.bind(this, event.target), 300);
  }
  async showTooltip(target) {
    if (
      !this.referenceElement ||
      this.referenceElement.dataset.dcTooltipId !== target.dataset.dcTooltipId ||
      this.cleanups.hasOwnProperty(target.dataset.dcTooltipId)
    )
      return;

    this.updateTooltipContent();
    this.watchTooltipContent();

    this.tooltip.style.display = 'block';
    this.cleanups[this.referenceElement.dataset.dcTooltipId] = this.addAutoUpdate();
    await this.updatePosition();
  }

  hideTooltip(_event) {
    Object.assign(this.tooltip.style, {
      left: '',
      top: '',
      display: ''
    });

    Object.assign(this.tooltipArrow.style, {
      left: '',
      top: '',
      right: '',
      bottom: ''
    });

    this.cleanupTooltips();
    this.referenceElement = undefined;

    this.stopWatchingTooltipContent();
  }
  cleanupTooltips() {
    for (const key of Object.keys(this.cleanups)) {
      this.cleanups[key]();
      delete this.cleanups[key];
    }
  }
  watchTooltipContent() {
    this.dataChangedObserver.disconnect();
    this.dataChangedObserver.observe(this.referenceElement, {
      attributes: true,
      attributeFilter: ['data-dc-tooltip']
    });
  }
  stopWatchingTooltipContent() {
    this.dataChangedObserver.disconnect();
  }
  updateTooltipContent() {
    this.tooltipContent.innerHTML = this.referenceElement.dataset.dcTooltip.trim();
  }
  async updatePosition() {
    const position = await computePosition(this.referenceElement, this.tooltip, {
      middleware: [
        offset(6),
        autoPlacement({ padding: 5 }),
        arrow({
          element: this.tooltipArrow
        }),
        hide({ strategy: 'referenceHidden' })
      ]
    });

    this.positionTooltip(position);
  }
  positionTooltip({ x, y, placement, middlewareData }) {
    Object.assign(this.tooltip.style, {
      left: `${x}px`,
      top: `${y}px`
    });

    const { x: arrowX, y: arrowY } = middlewareData.arrow;
    const { referenceHidden } = middlewareData.hide;

    if (referenceHidden) return this.hideTooltip();

    const staticSide = {
      top: 'bottom',
      right: 'left',
      bottom: 'top',
      left: 'right'
    }[placement.split('-')[0]];

    Object.assign(this.tooltipArrow.style, {
      left: arrowX != null ? `${arrowX}px` : '',
      top: arrowY != null ? `${arrowY}px` : '',
      right: '',
      bottom: '',
      [staticSide]: '-4px'
    });
  }
}

export default Tooltips;
