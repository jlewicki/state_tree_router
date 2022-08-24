# state_tree_router
`state_tree_router` is a Flutter package for for providing reactive application navigation in response to the state
transitions of a `tree_state_machine`.

## Features
`tree_state_router` enables the set of pages/screens of a Flutter application, and the transitions between them, to be
represented by a `TreeStateMachine` from the `tree_state_machine` package. It provides 

* A `StateTreeRouterDelegate` that adapts the states of state tree to a `Navigator` using Flutter's declarative 
routing API. 
* A `NestedStateMachineRouterDelegate` that adapts the states of a state tree nested within an outer state tree to a 
`Navigator`. For use with a router nested within an outer router with a `StateTreeRouterDelegate`.
* A set of `TreeStateBuilder` widgets for providing a visualization of an individual tree state.  Can be used with or
with the router delegatea. 

## Getting started


## Usage




TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder. 

```dart
const like = 'sample';
```

## Additional information

