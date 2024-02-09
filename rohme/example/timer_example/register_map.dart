import 'package:rohme/rohme.dart';


final RegisterMap registerMap = RegisterMap('master register map');

void initialiseRegisterMap()
{
  registerMap.addRegister('TIMER.TIME',0x000);

  Register control = registerMap.addRegister('TIMER.CONTROL',0x004);

  control.addField('START',(0,1) );
  control.addField('CONTINUOUS',(1,2) );
  control.addField('STOP',(2,3));

  registerMap.addRegister('TIMER.ELAPSED',0x008,accessType: AccessType.read);

  print('${registerMap.name}:');
  registerMap.map.forEach( (addr,r) { print('  $r'); });
}
