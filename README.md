<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages). 
-->

`tree_state_router` is a Flutter package for for providing reactive application navigation in response to the state
transition of a `tree_state_machine`.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting started

`tree_state_router` enables the set of pages/screens of a Flutter application, and the transitions between them, to be
represented by a `TreeStateMachine` (from the `tree_state_machine` package). It provides a `StateTreeRouterDelegate` 
implementation that adapts the states of state tree as pages of a `Navigator` using Flutters declarative routing API. 
The router delegate adjusts the current page of the `Navigator` as state transitions occur within the state machine.


## Usage

var 



TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder. 

```dart
const like = 'sample';
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more.
