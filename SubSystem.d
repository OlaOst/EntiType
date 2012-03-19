module SubSystem;

import Entity;


unittest
{

}


void update(Entity entity, float time)
{
  entity.position += entity.velocity * time;
}