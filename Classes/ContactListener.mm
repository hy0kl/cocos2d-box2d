/*
 *  ContactListener.mm
 *  PhysicsBox2d
 *
 *  Created by Steffen Itterheim on 17.09.10.
 *  Copyright 2010 Steffen Itterheim. All rights reserved.
 *
 */

#import "ContactListener.h"
#import "cocos2d.h"

/** 开始接触 */
void ContactListener::BeginContact(b2Contact* contact)
{
	b2Body* bodyA = contact->GetFixtureA()->GetBody();
	b2Body* bodyB = contact->GetFixtureB()->GetBody();
	CCSprite* spriteA = (CCSprite*)bodyA->GetUserData();
	CCSprite* spriteB = (CCSprite*)bodyB->GetUserData();
	
	if (spriteA != NULL && spriteB != NULL)
	{
		spriteA.color = ccMAGENTA;
		spriteB.color = ccMAGENTA;
	}
}

/** 结束接触 */
void ContactListener::EndContact(b2Contact* contact)
{
	b2Body* bodyA = contact->GetFixtureA()->GetBody();
	b2Body* bodyB = contact->GetFixtureB()->GetBody();
	CCSprite* spriteA = (CCSprite*)bodyA->GetUserData();
	CCSprite* spriteB = (CCSprite*)bodyB->GetUserData();
	
	if (spriteA != NULL && spriteB != NULL)
	{
		spriteA.color = ccWHITE;
		spriteB.color = ccWHITE;
	}
}
