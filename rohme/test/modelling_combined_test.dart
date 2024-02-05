/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

//
// A few abstract interfaces, some of which implement each other
//
abstract interface class MyInterface
{
  void remoteMessage( int n );
}

abstract interface class MyOtherInterface
{
  void otherMessage( int n );
}

abstract interface class CombinedInterface implements MyOtherInterface , MyInterface
{
}

abstract interface class SomeOtherInterface
{
  void yetAnotherMessage();
}

//
// this class allows us to call interface methods directly from the port
//
// ( because it implements MyInterface, then PortBase::noSuchMethod delegates
// to the underlying interface)
//
// This is only needed because we can't do class<IF> implements IF in Dart :(
//
class MyPort extends Port<MyInterface> implements MyInterface
{
  MyPort( super.name , [super.parent] );
}

//
// A Function based proxy.
//
// Proxies delegate all the methods in an interface to a Function object
// which will be assigned in the parent's constructor.
//
// This allows function aliasing, which is useful when a channel wants to
// present many versions of the same interface to the outside world.
//
// WISH LIST : it would be nice to be able to generate a Proxy from an interface
//
class MyProxy extends NamedComponent implements MyInterface
{
  MyProxy( super.name , [super.parent] );

  @override
  void remoteMessage( int n )
  {
    remoteMessageFunc( n );
  }

  late final void Function(int) remoteMessageFunc;
}

//
// A couple of implementations
//

//
// Note : we deliberately implement a fatter interface ('CombinedInterface')
// than the test actually needs ('MyInterface') to demonstrate that we
// can connect Port<IF> to an interface that implements IF.
//
class MyImp extends NamedComponent implements CombinedInterface
{
  MyImp( super.name , [super.parent] );

  @override
  void remoteMessage( int n )
  {
    print('$fullName: remoteMessage $n');
  }

  @override
  void otherMessage( int n )
  {
    print('$fullName: otherMessage $n');
  }
}

//
// We use this to demonstrate that attempted connections to the wrong
// kind of interface generate a helpful exception
//
class ErrorImp extends NamedComponent implements SomeOtherInterface
{
  ErrorImp( super.name , [super.parent] );

  @override
  void yetAnotherMessage()
  {
    print('$fullName yet another message');
  }
}

//
// The top level module
//
class Top extends Module
{
  late final Initiator initiator;
  late final Target target;

  Top( super.name , [super.parent] )
  {
    initiator = Initiator('initiator',this);
    target = Target('target',this);
  }

  // at the top level, we bind sibling ports to sibling exports, moving across the hierarchy
  @override
  void connect()
  {
    initiator.p1 <= target.e;
    initiator.p2 <= target.e;

    /*
    //
    // This now leads to a compile error
    //
    try
    {
      // this is an illegal connection :
      // we can't connect p1 ( port<myInterface> ) to eError ( SomeOtherInterface )

      initiator.p3 <= target.eError;
    }
    on Error catch( e , s )
    {
      print('$e');
    }
    */

    initiator.p4.implementedBy( target.other2remote );
  }
}

//
// An initiator, with ports and a run method
//
class Initiator extends Module
{
  late final MyPort p1;             // MyPort extends MyInterface
  late final Port<MyInterface> p2;
  late final Port<MyInterface> p3;
  late final MyPort p4;

  Initiator( super.name, [super.parenet] )
  {
    p1 = MyPort('p1',this);
    p2 = Port('p2',this);
    p3 = Port('p3',this);
    p4 = MyPort('p4',this);
  }

  @override
  Future<void> run () async
  {
    // because MyPort extends MyInterface, we can call method directly on the port
    p1.remoteMessage( 3 );

    // alternative calling techniques if we have not declared a specialised port
    p2().remoteMessage( 2 );
    p2.portIf.remoteMessage( 1 );

    /*
    // now leads to a compile error
    //
    try
    {
      // this is just nonsense - the argument to () has to be a port, an IMP or null
      p2 <= 7;
    }
    on Error catch( e )
    {
      print('$e');
    }
    */

    // p3 is incorrecly connected in 'top', so we don't attempt to call any of
    // its methods

    // this actually calls 'otherMessage' because it is connected to a proxy
    // in 'top'
    for( int i = 0; i < getConfig('iterations',component : this); i++ ) {
      p4.remoteMessage( i );
    }
  }
}

//
// A target, with exports and internal channels aka IMPs.
//
class Target extends Module
{
  late final Port<CombinedInterface> e;
  late final Port<SomeOtherInterface> eError;

  // used to make otherMessage "look like" a remoteMessage
  late final MyProxy other2remote;

  Target( super.name , [super.parent] )
  {
    imp = MyImp("channel",this);
    errorImp = ErrorImp("error_channel",this);

    e = Port('e',this);
    eError = Port('error',this);

    other2remote = MyProxy("other2remote",this);
    other2remote.remoteMessageFunc = ( int n ) { imp.otherMessage( n ); };
  }

  // in the target, we bind exports to implementations, moving down the hierarchy
  @override
  void connect()
  {
    e.implementedBy( imp );
    eError.implementedBy( errorImp );
  }

  late final MyImp imp;
  late final ErrorImp errorImp;
}

void main() async {
  test('combined test' , () {
    config['top.initiator.iterations'] = 10;

    simulate( () => Top('top') );
  });
}
