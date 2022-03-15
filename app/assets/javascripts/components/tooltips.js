import { computePosition, autoPlacement, autoUpdate, arrow, offset } from '@floating-ui/dom';

class Tooltips {
  constructor() {
    this.tooltip = document.getElementById('dc-tooltip');
    this.referenceElement;
    this.cleanup;

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
      e => e.dataset.dcTooltip !== undefined,
      this.addEventsForTooltip.bind(this)
    ]);
  }
  addEventsForTooltip(tooltip) {
    tooltip.addEventListener('mouseenter', this.showTooltip.bind(this));
    tooltip.addEventListener('mouseleave', this.hideTooltip.bind(this));
  }
  showTooltip(event) {
    if (!event.target.dataset.dcTooltip) return;

    this.referenceElement = event.target;
    this.tooltip.style.display = 'block';
    this.tooltipContent.innerHTML = this.referenceElement.dataset.dcTooltip.trim();

    this.updatePosition();
    this.cleanup = autoUpdate(this.referenceElement, this.tooltip, this.updatePosition.bind(this));
  }
  hideTooltip(_event) {
    this.tooltip.style.display = '';

    if (this.cleanup) this.cleanup();
  }
  updatePosition() {
    computePosition(this.referenceElement, this.tooltip, {
      middleware: [
        offset(6),
        autoPlacement({ padding: 5 }),
        arrow({
          element: this.tooltipArrow
        })
      ]
    }).then(this.positionTooltip.bind(this));
  }
  positionTooltip({ x, y, placement, middlewareData }) {
    Object.assign(this.tooltip.style, {
      left: `${x}px`,
      top: `${y}px`
    });

    const { x: arrowX, y: arrowY } = middlewareData.arrow;

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
