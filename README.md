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
First let's define a simple state machine that will capitalize a string.

```dart
class States {
  static const enterText = StateKey('simple_enterText');
  static const showUppercase = StateKey('simple_showUppercase');
  static const finished = StateKey('simple_finished');
}

enum Messages { finish }

class ToUppercase {
  ToUppercase(this.text);
  final String text;
}

class SimpleStateTree {
  StateTreeBuilder treeBuilder() {
    var b = StateTreeBuilder(initialState: States.enterText);
    
     b.state(_S.enterText, (b) {
      b.onMessage<ToUppercase>((b) => b.goTo(_S.showUppercase, payload: (ctx) => ctx.message.text));
    });

    b.dataState<String>(
      _S.showUppercase,
      InitialData.run((ctx) => (ctx.payload as String).toUpperCase()),
      (b) {
        b.onMessageValue(
          Messages.finish,
          (b) => b.goTo(SimpleStates.finished, payload: (ctx) => ctx.data),
        );
      },
    );

    b.finalDataState<String>(
      _S.finished,
      InitialData.run((ctx) => ctx.payloadOrThrow<String>()}),
      emptyFinalState,
    );

    return b;
  }
}
```

Next let's define pages that can display these states. As the user presses buttons, messages are dispatched to the state 
machine using the `currentState` parameter.

```dart
final enterTextPage = TreeStatePage.forState(SimpleStates.enterText, (buildContext, currentState) {
  var currentText = '';
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        StatefulBuilder(
          builder: (context, setState) => Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: TextField(
              onChanged: (val) => currentText = val,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter some text',
              ),
            ),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              child: const Text('To Uppercase'),
              onPressed: () => currentState.post(ToUppercase(currentText)),
            ),
          ),
        ]),
      ],
    ),
  );
});

final toUppercasePage = TreeStatePage.forDataState<String>(
  SimpleStates.showUppercase,
  (buildContext, text, currentState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Uppercase text: $text',
          style: const TextStyle(fontSize: 24),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            child: const Text('Done'),
            onPressed: () => currentState.post(Messages.finish),
          ),
        ),
      ],
    );
  },
);

final finishedPage = TreeStatePage.forDataState<String>(
   SimpleStates.finished,
   (buildContext, text, currentState) {
      return Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
            Text(
               'Final result: $text',
               style: const TextStyle(fontSize: 24),
            ),
         ],
      );
   },
);
```

Finally let's define an app that will perform routing based on the state transitions of the state machine. The 
`Router` is intitalized with a `StateTreeRouterDelegate`, and this router will detect state transitions and display
the page that corresponds to the current state of the state machine.
```dart
/// Now define an app
class SimpleApp extends StatefulWidget {
  const Simple({Key? key}) : super(key: key);
  @override
  State<App> createState() => _SimpleAppState();
}

class _SimpleAppState extends State<SimpleApp> {
   late final treeBuilder = SimpleStateMachine().treeBuilder();
   @override
   Widget build(BuildContext context) {
    return MaterialApp.router(
      routeInformationParser: StateTreeRouteInfoParser(treeBuilder.rootKey),
      routerDelegate: StateTreeRouterDelegate(
         stateMachine: TreeStateMachine(treeBuilder),
         scaffoldPages: true,
         pages: [
            enterTextPage,
            toUppercasePage,
            finishedPage
         ],
      ),
      color: Colors.amberAccent,
    );
  }
}
```

## Additional information

