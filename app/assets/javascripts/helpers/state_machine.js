export default class StateMachine {
  constructor(definition) {
    this.definition = definition;
    this.value = definition.initialState;
    this.inTransition = false;
  }
  async transition(event, { transition = [], enter = [], exit = [] } = {}) {
    if (this.inTransition) return this.warnInTransition(event);

    this.inTransition = true;
    const currentDefinition = this.definition[this.value];
    const destinationTransition = currentDefinition.transitions[event];
    if (!destinationTransition) return this.warnMissingTransition(event);

    const destinationState = this.destinationState(destinationTransition);
    const destinationStateDefinition = this.definition[destinationState];

    if (currentDefinition.actions?.onExit)
      await currentDefinition.actions.onExit(...exit);
    if (destinationTransition.action)
      await destinationTransition.action(...transition);
    if (destinationStateDefinition.actions?.onEnter)
      await destinationStateDefinition.actions.onEnter(...enter);

    this.value = destinationState;
    this.inTransition = false;

    return this.value;
  }

  destinationState(transition) {
    return typeof transition === "string" ? transition : transition.target;
  }

  warnInTransition(event) {
    console.warn(
      `Transition "${event}" ignored because another transition is already in progress. Current state: "${this.value}".`
    );
    return null;
  }

  warnMissingTransition(event) {
    this.inTransition = false;
    console.warn(
      `Missing transition for event "${event}" from state "${this.value}".`
    );
    return null;
  }
}
