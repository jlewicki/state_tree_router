import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

class TreeStateRouteParseResult {
  TreeStateRouteParseResult(this.routeRemainder, this.routeState, this.routePayload);
  final StateKey routeState;
  final Object? routePayload;
  final String routeRemainder;
}

class TreeStateRouteParser {
  TreeStateRouteParseResult? parseRoute(RouteInformation routeInfo) {
    return null;
  }
}

extension RoutableStateExtensionBuilder on StateExtensionBuilder {
  static const String routableMetadataKey = "RoutableStateExtensionBuilder.routable";
  static const String isRoutingHandlerMetadataKey = "RoutableStateExtensionBuilder.routeHandler";

  StateExtensionBuilder routable({TreeStateRouteParser? parser}) {
    metadata({routableMetadataKey: parser ?? TreeStateRouteParser()});
    return this;
  }

  static TreeStateRouteParser? getRouteParser(Map<String, Object> metadata) {
    return metadata[routableMetadataKey] as TreeStateRouteParser?;
  }

  StateExtensionBuilder isRoutingHandler() {
    if (extensionInfo.metadata.containsKey(isRoutingHandlerMetadataKey)) {
      throw StateError('State "${extensionInfo.key}" has already been marked as a route handler.');
    }
    var routingFilter = RoutingTreeStateFilter();
    metadata({isRoutingHandlerMetadataKey: routingFilter});
    filters([routingFilter]);
    return this;
  }
}

class RoutingTreeStateFilter extends TreeStateFilter {
  @override
  FutureOr<MessageResult> onMessage(
    MessageContext msgCtx,
    FutureOr<MessageResult> Function() next,
  ) {
    var msg = msgCtx.message;
    if (msg is RoutingMessage) {
      return msgCtx.goTo(msg.targetState, payload: msg.payload);
    }

    return next();
  }
}

class RoutingMessage {
  RoutingMessage(this.targetState, [this.payload]);
  final StateKey targetState;
  final Object? payload;
}
