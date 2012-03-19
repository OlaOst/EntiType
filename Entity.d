module Entity;

import std.algorithm;
import std.array;
import std.conv;
import std.json;
import std.stdio;
import std.string;
import std.typecons;
import std.variant;

import gl3n.linalg;


unittest
{
  scope(success) writeln(__FILE__ ~" unittests succeded");
  scope(failure) writeln(__FILE__ ~" unittests failed");  
  
  Entity entity;
  entity.name = "test";
  entity.position = vec2(1.0, 2.0);
  
  assert(entity.name == "test");
  assert(entity.position == vec2(1.0, 2.0), "Expected " ~ to!string(vec2(1.0, 2.0)) ~ ", got " ~ to!string(entity.position));
  
  Entity childEntity;
  childEntity.name = "child";
  
  entity.children = [childEntity];
  
  assert(entity.children[0].name == "child");
  
  
  string jsonString = `[ { "name" : "parent", "position" : [1.0, 2.0], "children" : [{ "name" : "child", "position" : [2.0, 1.0] }] } ]`;
  
  auto jsonTree = parseJSON(jsonString);
  
  auto entities = jsonToEntities(jsonTree);
  
  assert(entities.length == 1, "Expected 1 entity, got " ~ to!string(entities.length) ~ ": " ~ to!string(entities));
  assert(entities[0]["name"] == "parent", "Expected parent, got " ~ to!string(entities[0]["name"]));
  assert(entities[0]["position"].get!(float[]) == [1.0, 2.0]);//, "Expected " ~ to!string([1.0, 2.0]) ~ ", got " ~ to!string(entities[0]["position"]) ~ " of type " ~ to!string(typeid(entities[0]["position"])));
  
  assert(entities[0].name == "parent", "Expected \"parent\", got \"" ~ to!string(entities[0].name) ~ "\"");
  assert(entities[0].position == vec2(1.0, 2.0));
  assert(entities[0].children[0].name == "child");
}


template keyToType(string key, string type)
{
  static if (type == "vec2")
  {
    const char[] keyToType = `@property ` ~ type ~ ` ` ~ key ~ `() { return vec2(values["` ~ key ~ `"].get!(float[])); }` ~
                             `@property ` ~ type ~ ` ` ~ key ~ `(` ~ type ~ ` value) { float[] vector = value.vector; values["` ~ key ~ `"] = vector; return value; }`;
  }
  else
  {
    const char[] keyToType = `@property ` ~ type ~ ` ` ~ key ~ `() { assert(values["` ~ key ~ `"].hasValue()); assert(values["` ~ key ~ `"].peek!(` ~ type ~ `) !is null); return values["` ~ key ~ `"].get!(` ~ type ~ `); }` ~
                             `@property ` ~ type ~ ` ` ~ key ~ `(` ~ type ~ ` value) { values["` ~ key ~ `"] = value; return values["` ~ key ~ `"].get!(` ~ type ~ `); }`;
  }
}

struct Entity
{
  Variant[string] values;
  
  alias values this;
  
  mixin(keyToType!("name", "string"));
  mixin(keyToType!("position", "vec2"));
  mixin(keyToType!("velocity", "vec2"));
  mixin(keyToType!("children", "Entity[]"));
}


Entity[] jsonToEntities(JSONValue jsonRoot)
{
  Entity[] entities;
  
  if (jsonRoot.type == JSON_TYPE.ARRAY)
  {
    foreach (value; jsonRoot.array)
    {
      entities ~= jsonToEntities(value);
    }
  }
  else if (jsonRoot.type == JSON_TYPE.OBJECT)
  {
    Entity entity;
    
    foreach (key, value; jsonRoot.object)
    {
      if (value.type == JSON_TYPE.STRING)
        entity[key] = value.str;
      else if (value.type == JSON_TYPE.INTEGER)
        entity[key] = value.integer;
      else if (value.type == JSON_TYPE.FLOAT)
        entity[key] = value.floating;
      else if (value.type == JSON_TYPE.ARRAY)
      {
        if (key == "children")
        {
          entity[key] = jsonToEntities(value);
          
          assert(entity[key].type == typeid(Entity[]));
        }
        else if (key == "position")
          entity[key] = to!(float[])([value.array[0].floating, value.array[1].floating]);
        else
        {
          assert(false, "Cannot handle array type with key " ~ to!string(key));
        }
      }
      else if (value.type == JSON_TYPE.OBJECT)
      {
        entities ~= jsonToEntities(value);
      }
    }
    
    entities ~= entity;
  }
  else
  {
    assert(false);
  }
  
  return entities;
}
