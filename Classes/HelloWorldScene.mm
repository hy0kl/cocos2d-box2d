/**
//
//  HelloWorldScene.mm
//  PhysicsBox2d
//
//  Created by Steffen Itterheim on 16.09.10.
//  Copyright Steffen Itterheim 2010. All rights reserved.
//
//  improve by hy0kle@gmail.com
*/

#import "HelloWorldScene.h"

//Pixel to metres ratio. Box2D uses metres as the unit for measurement.
//This ratio defines how many pixels correspond to 1 Box2D "metre"
//Box2D is optimized for objects of 1x1 metre therefore it makes sense
//to define the ratio so that your most common object type is 1x1 metre.
#define PTM_RATIO 32

#define TILESIZE 32
#define TILESET_COLUMNS 9
#define TILESET_ROWS 19

/** 私有方法 */
@interface HelloWorld (PrivateMethods)
-(void) addSomeJoinedBodies:(CGPoint)pos;
-(void) addNewSpriteAt:(CGPoint)p;
@end

@implementation HelloWorld

+(id) scene
{
    CCScene *scene = [CCScene node];
    HelloWorld *layer = [HelloWorld node];
    [scene addChild: layer];
    return scene;
}

// convenience method to convert a CGPoint to a b2Vec2
-(b2Vec2) toMeters:(CGPoint)point
{
    return b2Vec2(point.x / PTM_RATIO, point.y / PTM_RATIO);
}

// convenience method to convert a b2Vec2 to a CGPoint
-(CGPoint) toPixels:(b2Vec2)vec
{
    return ccpMult(CGPointMake(vec.x, vec.y), PTM_RATIO);
}

-(id) init
{
    if ((self = [super init]))
    {
        // Construct a world object, which will hold and simulate the rigid bodies.
        /** 重力 */
        b2Vec2 gravity = b2Vec2(0.0f, -10.0f);
        /** 自动进入休眠 */
        bool allowBodiesToSleep = true;
        world = new b2World(gravity, allowBodiesToSleep);

        /** 接触监听 */
        contactListener = new ContactListener();
        world->SetContactListener(contactListener);

        // Define the static container body, which will provide the collisions at screen borders.
        /** 创建静态的盒子世界的边界 */
        b2BodyDef containerBodyDef;
        b2Body* containerBody = world->CreateBody(&containerBodyDef);

        // for the ground body we'll need these values
        CGSize screenSize = [CCDirector sharedDirector].winSize;
        /** 单位换算 */
        float widthInMeters = screenSize.width / PTM_RATIO;
        float heightInMeters = screenSize.height / PTM_RATIO;

        b2Vec2 lowerLeftCorner  = b2Vec2(0, 0);
        b2Vec2 lowerRightCorner = b2Vec2(widthInMeters, 0);
        b2Vec2 upperLeftCorner  = b2Vec2(0, heightInMeters);
        b2Vec2 upperRightCorner = b2Vec2(widthInMeters, heightInMeters);

        // Create the screen box' sides by using a polygon assigning each side individually.
        b2PolygonShape screenBoxShape;
        /** 密度 */
        int density = 0;

        // bottom
        screenBoxShape.SetAsEdge(lowerLeftCorner, lowerRightCorner);
        containerBody->CreateFixture(&screenBoxShape, density);

        // top
        screenBoxShape.SetAsEdge(upperLeftCorner, upperRightCorner);
        containerBody->CreateFixture(&screenBoxShape, density);

        // left side
        screenBoxShape.SetAsEdge(upperLeftCorner, lowerLeftCorner);
        containerBody->CreateFixture(&screenBoxShape, density);

        // right side
        screenBoxShape.SetAsEdge(upperRightCorner, lowerRightCorner);
        containerBody->CreateFixture(&screenBoxShape, density);

        /** 操作提示 */
        CCLabelTTF* label = [CCLabelTTF labelWithString:@"Tap screen" fontName:@"Marker Felt" fontSize:32];
        [self addChild:label];
        [label setColor:ccc3(222, 222, 255)];
        label.position = CGPointMake(screenSize.width / 2, screenSize.height - 50);

        // Use the orthogonal tileset for the little boxes
        /** 使用批量的瓦片地图作为精灵背景 */
        CCSpriteBatchNode* batch = [CCSpriteBatchNode batchNodeWithFile:@"dg_grounds32.png" capacity:TILESET_ROWS * TILESET_COLUMNS];
        [self addChild:batch z:0 tag:kTagBatchNode];

        // Add a few objects initially
        /** 始初化界面上的一组精灵 */
        for (int i = 0; i < 9; i++)
        {
            [self addNewSpriteAt:CGPointMake(screenSize.width / 2, screenSize.height / 2)];
        }

        /** 空中游荡的刚体精灵 */
        [self addSomeJoinedBodies:CGPointMake(screenSize.width / 4, screenSize.height - 50)];

        /** 启动 */
        [self scheduleUpdate];

        /** 开启触控 */
        self.isTouchEnabled = YES;

        startTouch = CGPointZero;
    }

    return self;
}

-(void) dealloc
{
    delete contactListener;
    delete world;

    // don't forget to call "super dealloc"
    [super dealloc];
}

-(CCSprite*) addRandomSpriteAt:(CGPoint)pos
{
    CCSpriteBatchNode* batch = (CCSpriteBatchNode*)[self getChildByTag:kTagBatchNode];

    int idx = CCRANDOM_0_1() * TILESET_COLUMNS;
    int idy = CCRANDOM_0_1() * TILESET_ROWS;
    CGRect tileRect = CGRectMake(TILESIZE * idx, TILESIZE * idy, TILESIZE, TILESIZE);
    CCSprite* sprite = [CCSprite spriteWithBatchNode:batch rect:tileRect];
    sprite.position = pos;
    [batch addChild:sprite];

    return sprite;
}

-(void) bodyCreateFixture:(b2Body*)body postion:(CGPoint)pos
{
    // Define another box shape for our dynamic bodies.
    b2PolygonShape dynamicBox;
    float tileInMeters = TILESIZE / PTM_RATIO;
    /** 设置形状 */
    dynamicBox.SetAsBox(tileInMeters * 0.5f, tileInMeters * 0.5f);

    // Define the dynamic body fixture.
    b2FixtureDef fixtureDef;
    fixtureDef.shape = &dynamicBox;
    fixtureDef.density = 0.3f;
    fixtureDef.friction = 0.5f;
    fixtureDef.restitution = 0.6f;
    body->CreateFixture(&fixtureDef);

    /** 给刚体加外力 { */
    float distance = ccpDistance(pos, startTouch);
    if (distance < 5)
    {
        return;
    }

    float cos = (pos.x - startTouch.x)/distance;
    float sin = (pos.y - startTouch.y)/distance;
    distance /= PTM_RATIO;

    float fix_factor = 1.3;
    b2Vec2 vel = body->GetLinearVelocity();
    float m = body->GetMass();// the mass of the body
    float t = 1.0f / 60.0f; // the time you set
    b2Vec2 desiredVel = b2Vec2(fix_factor * distance * cos, fix_factor * distance * sin); // the vector speed you set
    b2Vec2 velChange = desiredVel - vel;

    b2Vec2 force;
    force.x = m * velChange.x / t;
    force.y = m * velChange.y / t;

    body->ApplyForce(force, body->GetWorldCenter());
    body->SetLinearDamping(0.2f);
    /** } */
}

-(void) addSomeJoinedBodies:(CGPoint)pos
{
    // Create a body definition and set it to be a dynamic body
    b2BodyDef bodyDef;
    /** 动态刚体 */
    bodyDef.type = b2_dynamicBody;

    // position must be converted to meters
    /** 物理引擎使用的是国际单位制 KMS */
    bodyDef.position = [self toMeters:pos];
    bodyDef.position = bodyDef.position + b2Vec2(-1, -1);
    bodyDef.userData = [self addRandomSpriteAt:pos];
    b2Body* bodyA = world->CreateBody(&bodyDef);
    [self bodyCreateFixture:bodyA postion:pos];

    bodyDef.position = [self toMeters:pos];
    bodyDef.userData = [self addRandomSpriteAt:pos];
    b2Body* bodyB = world->CreateBody(&bodyDef);
    [self bodyCreateFixture:bodyB postion:pos];

    bodyDef.position = [self toMeters:pos];
    bodyDef.position = bodyDef.position + b2Vec2(1, 1);
    bodyDef.userData = [self addRandomSpriteAt:pos];
    b2Body* bodyC = world->CreateBody(&bodyDef);
    [self bodyCreateFixture:bodyC postion:pos];

    /** 转动关节 */
    b2RevoluteJointDef jointDef;
    jointDef.Initialize(bodyA, bodyB, bodyB->GetWorldCenter());
    /**
    // 加入阻尼和限制马达
    jointDef.lowerAngle = -0.5f * b2_pi; // -90 degrees
    jointDef.upperAngle = 0.25f * b2_pi; // 45 degrees jointDef.enableLimit = true;
    jointDef.maxMotorTorque = 10.0f;
    jointDef.motorSpeed = 0.0f;
    jointDef.enableMotor = true;
    */
    bodyA->GetWorld()->CreateJoint(&jointDef);

    jointDef.Initialize(bodyB, bodyC, bodyC->GetWorldCenter());
    bodyA->GetWorld()->CreateJoint(&jointDef);

    // create an invisible static body to attach to
    bodyDef.type = b2_staticBody;
    bodyDef.position = [self toMeters:pos];
    b2Body* staticBody = world->CreateBody(&bodyDef);
    jointDef.Initialize(staticBody, bodyA, bodyA->GetWorldCenter());
    bodyA->GetWorld()->CreateJoint(&jointDef);
}

-(void) addNewSpriteAt:(CGPoint)pos
{
    // Create a body definition and set it to be a dynamic body
    b2BodyDef bodyDef;
    bodyDef.type = b2_dynamicBody;

    // position must be converted to meters
    bodyDef.position = [self toMeters:pos];

    // assign the sprite as userdata so it's easy to get to the sprite when working with the body
    bodyDef.userData = [self addRandomSpriteAt:pos];
    b2Body* body = world->CreateBody(&bodyDef);

    [self bodyCreateFixture:body postion:pos];
}

-(void) update:(ccTime)delta
{
    // The number of iterations influence the accuracy of the physics simulation. With higher values the
    // body's velocity and position are more accurately tracked but at the cost of speed.
    // Usually for games only 1 position iteration is necessary to achieve good results.
    float timeStep = 0.03f;
    int32 velocityIterations = 8;
    int32 positionIterations = 1;
    world->Step(timeStep, velocityIterations, positionIterations);

    // for each body, get its assigned sprite and update the sprite's position
    for (b2Body* body = world->GetBodyList(); body != nil; body = body->GetNext())
    {
        CCSprite* sprite = (CCSprite*)body->GetUserData();
        if (sprite != NULL)
        {
            /**
            //弹道旋转
            b2Vec2 vel = body->GetLinearVelocity();        //buBody 代表子弹刚体对象
            float  ang = atanf(vel.y / vel.x);
            body->SetTransform(body->GetPosition(), ang);
            */

            // update the sprite's position to where their physics bodies are
            sprite.position = [self toPixels:body->GetPosition()];
            float angle = body->GetAngle();
            /** 将弧度转为角度 */
            sprite.rotation = CC_RADIANS_TO_DEGREES(angle) * -1;
        }
    }
}

-(CGPoint) locationFromTouch:(UITouch*)touch
{
    CGPoint touchLocation = [touch locationInView: [touch view]];
    return [[CCDirector sharedDirector] convertToGL:touchLocation];
}

-(CGPoint) locationFromTouches:(NSSet*)touches
{
    return [self locationFromTouch:[touches anyObject]];
}

// 监听首次触发事件
- (void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchLocation = [self locationFromTouches:touches];
    startTouch = touchLocation;
    CCLOG(@"ccTouchesBegan at {x: %f, y: %f}", touchLocation.x, touchLocation.y);
}

// 触摸事件: 当手指在屏幕上进行移动
- (void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchLocation = [self locationFromTouches:touches];
    CCLOG(@"ccTouchesMoved at {x: %f, y: %f}", touchLocation.x, touchLocation.y);
}

// 触摸事件: 当手指从屏幕抬起时调用的方法
-(void) ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    //Add a new body/atlas sprite at the touched location
    for (UITouch* touch in touches)
    {
        CGPoint location = [self locationFromTouches:touches];
        CCLOG(@"new sprite at: {x: %f, y: %f}", location.x, location.y);
        [self addNewSpriteAt:location];
    }
}

@end
