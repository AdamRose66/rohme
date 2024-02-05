/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'module.dart';

///
/// The config DB is just a map of nullable objects, indexed by string
///
/// There are some access methods and some groovy exceptions, but they
/// are not compulsory or even recommended.
///
/// There is an expectation that NamedComponents look up 'local' configs
/// at NamedComponent.fullName.<configName> eg m1.c1.my_config
///
/// The config db can contain absolutely anything - values, Functions,
/// instances, types, whatever you want !
///
/// Regex searches can be done in the usual Dart way. No need to reinvent the
/// wheel.
///
Map<String,Object?> config = {};

/// if the component is not null, prefix its Hierarchical name
String calculateFullName( String name , NamedComponent? component )
{
  if( component == null )
  {
    return name;
  }
  return '${component.fullName}.$name';
//  return component.fullName + '.' + name;
}

/// Returns a possibly null config of type T from component?.name.
///
/// If there is a config at component?.name, and it is of the wrong type,
/// throw [ConfigWrongType]
///
/// If there is no config at component?.name, throw ConfigWrongType
///
T? getConfigNullable<T>( String name , [NamedComponent? component] )
{
  String fullName = calculateFullName( name , component );

  if( !config.containsKey( fullName ) )
  {
    throw ConfigDoesNotExist( fullName ); // config does not exist
  }

  Object? o = config[fullName];

  if( o == null )
  {
    return null; // config exists, and its value is null
  }

  if( o is! T )
  {
    throw ConfigWrongType<T>( fullName , o ); // config exists, but its the wrong type
  }

  return o as T;
}

/// Returns a non null T from component?.name
///
/// If component?.name exists and is a T, return it.
/// If component?.name does not exist, return [defaultValue] if default is not null
///
/// Throws [ConfigDoesNotExist] if there is nothing at component?.name and there
/// is no default.
///
/// Throws [ConfigIsNull] if component?.name exists and is null.
///
T getConfig<T>( String name , {NamedComponent? component,T? defaultValue} )
{
  T? t;

  try
  {
    t = getConfigNullable( name , component );
  }
  on ConfigDoesNotExist
  {
    if( defaultValue == null )
    {
      rethrow;
    }
    return defaultValue;
  }

  if( t == null )
  {
    // config might exist, but its value could be null
    throw ConfigIsNull( calculateFullName( name , component ) );
  }

  return t;
}

/// a based class for the other exceptions in this library
abstract class ConfigException implements Exception
{
  final String configName;

  ConfigException( this.configName );

  @override
  String toString();
}

/// An exception raised when a config does not exist
class ConfigDoesNotExist extends ConfigException
{
  ConfigDoesNotExist( super.configName );

  @override
  String toString()
  {
    return 'there is no config at $configName';
  }
}

/// An exception raised when a config is unexpectedly null
class ConfigIsNull extends ConfigException
{
  ConfigIsNull( super.configName );

  @override
  String toString()
  {
    return 'the config at $configName is null';
  }
}

/// An exception raised when a config exists but is of the wrong type
class ConfigWrongType<T> extends ConfigException
{
  final Object actual;

  ConfigWrongType( super.configName , this.actual );

  @override
  String toString()
  {
    return 'config item at $configName exists but its type $actual.runtimeType is not a $T';
  }
}
