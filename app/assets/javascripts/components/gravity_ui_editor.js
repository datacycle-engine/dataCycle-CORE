import CalloutHelpers from '../helpers/callout_helpers';

const positions = {
  top: {
    value: 'no',
    top: '0',
    left: '50%',
    transform: 'translateX(-50%)',
    iconClass: 'fa-arrow-up'
  },
  'top-right': {
    value: 'noea',
    top: '0',
    right: '0',
    rotate: '45deg',
    iconClass: 'fa-arrow-up'
  },
  right: {
    value: 'ea',
    top: '50%',
    right: '0',
    rotate: '90deg',
    transform: 'translateY(-50%)',
    iconClass: 'fa-arrow-up'
  },
  'bottom-right': {
    value: 'soea',
    bottom: '0',
    right: '0',
    rotate: '135deg',
    iconClass: 'fa-arrow-up'
  },
  bottom: {
    value: 'so',
    bottom: '0',
    left: '50%',
    rotate: '-180deg',
    transform: 'translateX(-50%)',
    iconClass: 'fa-arrow-up'
  },
  'bottom-left': {
    value: 'sowe',
    bottom: '0',
    left: '0',
    rotate: '-135deg',
    iconClass: 'fa-arrow-up'
  },
  left: {
    value: 'we',
    top: '50%',
    left: '0',
    rotate: '-90deg',
    transform: 'translateY(-50%)',
    iconClass: 'fa-arrow-up'
  },
  'top-left': {
    value: 'nowe',
    top: '0',
    left: '0',
    rotate: '-45deg',
    iconClass: 'fa-arrow-up'
  },
  center: {
    value: 'ce',
    top: '50%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    iconClass: 'fa-circle'
  }
};

class GravityUiEditor {
  constructor(button) {
    this.button = button;
    this.button.classList.add('dcjs-gravity-ui-editor');
    this.gravitySelecorIcons = [];
    this.thumbContainer = null;
    this.thingId = this.button.dataset.thingId;
    this.gravityInfo = JSON.parse(this.button.dataset.gravityInfo);
    this.gravity = this.button.dataset.gravity || null;
    this.buttonText = this.button.innerHTML;
    this.setUp();
  }

  setUp() {
    const imageContainer = this.button.closest('.image');
    this.thumbContainer = imageContainer.querySelector('.thumb');
    this.addEventListeners();
  }

  addEventListeners() {
    this.button.addEventListener('click', e => {
      if (this.button.classList.contains('active')) {
        this.button.classList.remove('active');
        this.thumbContainer.classList.remove('gravity-control');
        this.removeGravitySelectors();
        this.button.innerHTML = this.buttonText;
      } else {
        this.button.classList.add('active');
        this.thumbContainer.classList.toggle('gravity-control');
        for (const position in positions) {
          this.createGravitySelector(position);
        }
        this.button.innerHTML = e.currentTarget.dataset.editorActiveText;
      }
      this.toggleImageLinkInteractivity();
    });
  }

  toggleImageLinkInteractivity() {
    const imageLink = this.thumbContainer.querySelector('a');
    if (!imageLink) return;
    if (this.button.classList.contains('active')) {
      imageLink.style.cursor = 'default';
      imageLink.style.pointerEvents = 'none';
    } else {
      imageLink.style = '';
    }
  }

  createGravitySelector(position) {
    const gravitySelector = document.createElement('button');
    gravitySelector.innerHTML = `<i class="fa ${positions[position].iconClass}" aria-hidden="true"></i>`;
    const gravityInfo = this.gravityInfo.find(info => info.gravity === positions[position].value);
    gravitySelector.setAttribute('data-gravity', gravityInfo.id);
    gravitySelector.setAttribute('data-dc-tooltip', gravityInfo.name);
    gravitySelector.classList.add('gravity-icon');
    if (this.gravity === gravityInfo.id) {
      gravitySelector.classList.add('gravity-icon--active');
    }
    gravitySelector.style.top = positions[position].top;
    gravitySelector.style.left = positions[position].left;
    gravitySelector.style.right = positions[position].right;
    gravitySelector.style.bottom = positions[position].bottom;
    if (positions[position].transform) {
      gravitySelector.style.transform = positions[position].transform;
    }
    if (positions[position].rotate) {
      gravitySelector.style.transform += ` rotate(${positions[position].rotate})`;
    }
    this.gravitySelecorIcons.push(gravitySelector);
    gravitySelector.addEventListener('mouseenter', e => {
      for (const icon of this.gravitySelecorIcons) {
        if (icon !== e.target) {
          icon.setAttribute('data-hide', 'true');
        } else {
          icon.setAttribute('data-pale', 'true');
        }
      }

      this.thumbContainer.appendChild(this.createPreviewBox(position));
    });

    gravitySelector.addEventListener('mouseleave', () => {
      this.thumbContainer.removeChild(this.thumbContainer.querySelector('#gravity-preview-box'));
      for (const icon of this.gravitySelecorIcons) {
        icon.removeAttribute('data-hide');
        icon.removeAttribute('data-pale');
      }
    });

    gravitySelector.addEventListener('click', e => {
      const target = e.currentTarget;
      let gravityConceptId = target.dataset.gravity;
      if (target.classList.contains('gravity-icon--active')) {
        gravityConceptId = '';
      }
      DataCycle.httpRequest(`/things/${this.thingId}/update_gravity`, {
        method: 'PATCH',
        body: {
          gravity: gravityConceptId
        }
      })
        .then(data => {
          this.button.dataset.gravity = gravityConceptId;
          this.gravity = gravityConceptId;
          for (const icon of this.gravitySelecorIcons) {
            if (icon !== target) {
              icon.classList.remove('gravity-icon--active');
            } else {
              if (gravityConceptId === '') {
                icon.classList.remove('gravity-icon--active');
                I18n.t('frontend.gravity_editor.success_reset').then(text => {
                  CalloutHelpers.show(text, 'success');
                });
              } else {
                icon.classList.add('gravity-icon--active');
                I18n.t('frontend.gravity_editor.success_set', { data: gravityInfo.name }).then(text => {
                  CalloutHelpers.show(text, 'success');
                });
              }
            }
          }
        })
        .catch(error => {
          I18n.t('frontend.gravity_editor.error').then(text => {
            CalloutHelpers.show(text, 'error');
          });
        });
    });
    this.thumbContainer.appendChild(gravitySelector);
  }

  createPreviewBox(position) {
    const box = document.createElement('div');
    box.id = 'gravity-preview-box';
    box.classList.add('gravity-preview-box');
    const imageDimensions = this.thumbContainer.querySelector('img').getBoundingClientRect();
    box.style.width = `${0.8 * Math.min(imageDimensions.width, imageDimensions.height)}px`;
    box.style.aspectRatio = '1/1';
    box.style.top = positions[position].top;
    box.style.left = positions[position].left;
    box.style.right = positions[position].right;
    box.style.bottom = positions[position].bottom;
    box.style.transform = positions[position].transform;
    return box;
  }

  removeGravitySelectors() {
    for (const icon of this.gravitySelecorIcons) {
      this.thumbContainer.removeChild(icon);
    }
    this.gravitySelecorIcons = [];
  }
}

export default GravityUiEditor;
