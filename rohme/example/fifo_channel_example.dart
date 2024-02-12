/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:rohme/rohme.dart';

class Top extends Module
{
  late final Producer producer;
  late final Consumer consumer;
  late final FifoModule<int> fifo;

  Top( super.name , [super.parent] )
  {
    producer = Producer('producer',this);
    consumer = Consumer('consumer',this);
    fifo = FifoModule('fifo' , this );
  }

  @override
  void connect()
  {
    producer.putPort <= fifo.putExport;
    consumer.getPort <= fifo.getExport;
  }
}

class Producer extends Module
{
  late final PutPort putPort;

  Producer( super.name , [super.parent] )
  {
    putPort = PutPort('putPort',this);
  }

  @override
  void run() async
  {
    mPrint('run');
    for( int i = 0; i < 10; i++ )
    {
      mPrint('about to put $i');
      await putPort.put( i );
      await Future.delayed( Duration( microseconds : 10 ) );
    }
  }
}

class Consumer extends Module
{
  late final GetPort getPort;

  Consumer( super.name , [super.parent] )
  {
    getPort = GetPort('getPort',this);
  }

  @override
  void run() async
  {
    mPrint('run');
    for( int i = 0; i < 10; i++ )
    {
      int v = await( getPort.get() );
      mPrint('just got $v');
    }
  }
}

//
// convenience ports so that we can directly access put and get in the ports
//
class PutPort extends Port<FifoPutIf<int>> implements FifoPutIf<int>
{
  PutPort( super.name , [super.parent] );
}

class GetPort extends Port<FifoGetIf<int>> implements FifoGetIf<int>
{
  GetPort( super.name , [super.parent] );
}

void main() {
//  Top top = Top('top');

  simulateModel( () { return Top('top'); } );
}
