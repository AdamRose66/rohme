/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:mirrors';

import 'module.dart';

//
// TBD : add some ( possibly optional ) subtypes / mixins which provide
// hierarchy / role checking check child.p -> p -> e -> child.e
// ( ie something like sc_port/sc_export )
//
// TBD : add bidirectional initiator<REQ_IF,RSP_IF> and target<REQ_IF,RSP_IF>
// where REQ_IF is initiator -> target and RSP_IF is target -> Initiator.
// This would be the underlying mechanism for a Rohd/Dart TLM 2.0 equivalent.
//
// TBD : port arrays
//

/// A non-generic abstract PortBase class
///
/// This class is used by the Rohme infrastructure. [Port] is the user visible
/// class.
///
abstract class PortBase extends NamedComponent {
  PortBase(super.name, [super.parent]);

  /// the entry point used by the infrastructure to do the port connections
  void doConnections();

  /// isStartPort true then this is an inappropriate place to call doConnections
  bool get isStartPort => _isStartPort;

  /// a flag to control debug output
  bool debugConnections = true;

  bool _isStartPort = true;
}

/// A [Module] aware proxy for an interface of type IF.
///
/// There are three things necessary for a viable Modelling environment :
/// - a model of time ( ie a scheduler )
/// - a module hierarchy
/// - ports or proxies that allow remote calling of abstract interfaces
///
/// Ports are connected in chains which span the module hierarchy. Connections
/// take one of four forms:
/// - up : child.port <= parentPort;
/// - across : sibling1.port <= sibling2.export;
/// - down : parentExport <= child.export
/// - implementation : export.implementedBy( implementation );
///
/// The [Port] and simulator infrastructure copies the interface that finally
/// implements the interface at the far end of the chain to all the ports
/// connected to it.
///
/// This allows behavioural code in any of the modules that contains one of the
/// ports in the chain to direcly call the implementation method at the far end
/// of the chain.
///
/// A mechanism like this was first implemented in SystemC and then copied over
/// into SystemVerilog ( eg tlm and analysis ports ).
///
/// Such a mechanism can be used ( and has been used in SystemC ) as the basis
/// upon which to build RTL signal interfaces.
///
class Port<IF extends Object> extends PortBase {
  Port(super.name, [super.parent]);

  /// The Port to which this port is connected.
  Port<IF>? connectedTo;

  /// Connects to other ports of type Port<TO_IF extends IF> ( because of
  /// generic invariance ). Compile error if IF types are not compatible
  operator <=(Port<IF> p) {
    connectedTo = p;

    //
    // mark the port we are connecting to as an inappropriate place
    // from which to call doConnections
    //
    p._isStartPort = false;

    if (debugConnections) {
      print(
          'Connections Debug: Connecting $fullName type $runtimeType to ${p.fullName} type ${p.runtimeType}');
    }
  }

  /// A convenience for getting the interface from the port and calling its methods
  /// ```dart
  /// p().read( addr , data );
  /// ```
  /// where p does *not* implement IF
  ///
  IF call() {
    return portIf;
  }

  ///
  /// delegates method call to portIf
  ///
  /// Note : this only works if the Port class implements the IF
  ///
  /// If that is the case, then we can do for example
  /// ```dart
  /// p.read( addr , data );
  /// ```
  /// where read is a method in IF
  ///
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return reflect(portIf).delegate(invocation);
  }

  /// Ends the port connection chain by connecting to a final implementation.
  ///
  /// Used externally to connect a (Ex)Port to an interface
  ///
  /// Also used internally by _doConnections(.)
  ///
  void implementedBy(IF to, [bool? debug]) {
    debug ??= debugConnections;

    _if = to;

    if (debug) {
      String toName = 'unknown';

      if (to is NamedComponent) {
        toName = to.fullName;
      }

      print(
          'Connections Debug: Port $fullName type $runtimeType is implemented by $toName type $to.runtimeType');
    }
  }

  /// Connects interfaces backwards along the port connection chain
  @override
  void doConnections() {
    if (connectedTo != null) {
      _doConnections(connectedTo!, debugConnections);
    }
  }

  /// Recurses forwards along the port connection chain, using implementedBy to
  /// copy the final implementation backwards along the chain as it returns
  void _doConnections(Port<IF> to, bool debug) {
    if (_if != null) {
      // we've been here before, so don't recurse again
      return;
    }

    if (to.connectedTo != null) {
      to._doConnections(to.connectedTo!, debug);
    }

    // assign from the 'to' end of the connection chain backwards along the chain
    // the net effect is that an interface moves backwards along the chain of
    // connection from the furthest "connectedTo" to the nearest "connectedFrom"

    implementedBy(connectedTo!.portIf, debug);
  }

  /// The actual underlying interface, ultimately sourced from the end of the
  /// connectedTo chain.
  ///
  /// Throws [ProbableConnectionError] if a module attempts to get the port
  /// when there is no interface.
  ///
  IF get portIf {
    if (_if == null) {
      throw ProbableConnectionError(this);
    }
    return _if!;
  }

  IF? _if;
}

/// Used by [Port] when there is no interface on this Port.
class ProbableConnectionError extends Error {
  PortBase p;

  ProbableConnectionError(this.p);

  @override
  String toString() {
    return 'Port Connection Error: null interface on $p.fullName type $runtimeType. This indicates some kind of connection error.';
  }
}
