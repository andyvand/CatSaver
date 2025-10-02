//
//  CatSaverView.m
//  CatSaver
//
//  Created by Andy Vandijck on 02/10/2025.
//

#import "CatSaverView.h"
#import <SceneKit/SceneKit.h>

@interface CatSaverView () {
    NSPoint _catPos;        // Center position of the cat
    NSSize  _catSize;       // Overall size of the cat
    NSPoint _catVel;        // Velocity per frame
    BOOL    _facingRight;   // Direction the cat faces
    CGFloat _tailPhase;     // Tail wag animation phase
    BOOL    _isPreview;     // Store preview flag for sizing

    SCNView *_scnView;
    SCNNode *_cameraNode;
    SCNNode *_catRoot;
    SCNNode *_catModel;
    SCNNode *_tailNode;
    SCNNode *_frontLegNode;
    SCNNode *_backLegNode;
    SCNNode *_ambientLightNode;
    SCNNode *_lightNode;
    SCNNode *_catSpotLightNode;
    SCNMaterial *_furMat;
    SCNMaterial *_furLightMat;
    SCNMaterial *_eyeMat;
    SCNMaterial *_noseMat;
    CGFloat _catZ;
    CGFloat _catVZ;
    CGFloat _depthRange;
    NSTimeInterval _zAnimStartTime;
}
@end

@implementation CatSaverView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/120.0];
        _isPreview = isPreview;
        NSRect b = self.bounds;
        // Set a base size relative to the view
        CGFloat base = MIN(NSWidth(b), NSHeight(b));
        if (base <= 0) base = 200; // Fallback
        CGFloat scale = isPreview ? 0.18 : 0.28;
        _catSize = NSMakeSize(MAX(60, base * scale), MAX(40, base * scale * 0.7));
        // Randomize starting position within bounds margins
        CGFloat modelScale = 0.25; // Match _catModel scale for visual size
        CGFloat marginX = _catSize.width * 0.6 * modelScale;
        CGFloat marginY = _catSize.height * 0.6 * modelScale;
        CGFloat x = (CGFloat)arc4random_uniform((uint32_t)MAX(1, (NSWidth(b)  > marginX*2 ? (NSWidth(b)  - marginX*2) : 1))) + marginX;
        CGFloat y = (CGFloat)arc4random_uniform((uint32_t)MAX(1, (NSHeight(b) > marginY*2 ? (NSHeight(b) - marginY*2) : 1))) + marginY;
        _catPos = NSMakePoint(x, y);
        // Velocity: pixels per frame
        CGFloat speed = MAX(1.5, _catSize.width / 80.0);
        CGFloat speedY = MAX(1.0, _catSize.height / 90.0);
        BOOL right = arc4random_uniform(2) == 0;
        BOOL up = arc4random_uniform(2) == 0;
        _catVel = NSMakePoint(right ? speed : -speed, up ? speedY : -speedY);
        _facingRight = right;
        _tailPhase = 0.0;
        _depthRange = MAX(10.0, _catSize.width * 0.6);
        CGFloat speedZ = MAX(0.5, _catSize.width / 200.0);
        BOOL forward = arc4random_uniform(2) == 0;
        _catZ = 0.0;
        _catVZ = forward ? speedZ : -speedZ;

        [self setupSceneKit];
    }
    return self;
}

- (void)setupSceneKit
{
    // Create and attach an SCNView to render 3D content
    _scnView = [[SCNView alloc] initWithFrame:self.bounds];
    _scnView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _scnView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    _scnView.allowsCameraControl = NO;
    _scnView.backgroundColor = [NSColor colorWithCalibratedWhite:0.06 alpha:1.0];

    SCNScene *scene = [SCNScene scene];
    _scnView.scene = scene;
    _scnView.playing = YES;
    _scnView.rendersContinuously = YES;
    [self addSubview:_scnView positioned:NSWindowAbove relativeTo:nil];

    // Camera (orthographic so 1 world unit ~= 1 point with scale set in drawRect)
    _cameraNode = [SCNNode node];
    _cameraNode.camera = [SCNCamera camera];
    _cameraNode.camera.usesOrthographicProjection = YES;
    _cameraNode.position = SCNVector3Make(0, 0, 300);
    _cameraNode.camera.fieldOfView = 45.0;
    _cameraNode.camera.zNear = 1.0;
    _cameraNode.camera.zFar = 2000.0;
    [scene.rootNode addChildNode:_cameraNode];

    // Lighting
    _ambientLightNode = [SCNNode node];
    _ambientLightNode.light = [SCNLight light];
    _ambientLightNode.light.type = SCNLightTypeAmbient;
    _ambientLightNode.light.color = [NSColor colorWithCalibratedWhite:0.5 alpha:1.0];
    [scene.rootNode addChildNode:_ambientLightNode];

    _lightNode = [SCNNode node];
    _lightNode.light = [SCNLight light];
    _lightNode.light.type = SCNLightTypeDirectional;
    _lightNode.light.color = [NSColor whiteColor];
    _lightNode.eulerAngles = SCNVector3Make(-M_PI_4, -M_PI_4, 0);
    _lightNode.light.castsShadow = YES;
    _lightNode.light.shadowRadius = 8.0;
    _lightNode.light.shadowColor = [NSColor colorWithCalibratedWhite:0 alpha:0.4];
    [scene.rootNode addChildNode:_lightNode];

    // Root node for positioning the cat in screen space
    _catRoot = [SCNNode node];
    [scene.rootNode addChildNode:_catRoot];

    // Model container to flip left/right by rotating around Y
    _catModel = [SCNNode node];
    _catModel.scale = SCNVector3Make(0.25f, 0.25f, 0.25f);
    [_catRoot addChildNode:_catModel];

    // Materials matching 2D palette (store as ivars for dynamic color changes)
    _furMat = [SCNMaterial material];
    _furMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.20 green:0.22 blue:0.26 alpha:1.0];
    _furLightMat = [SCNMaterial material];
    _furLightMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.28 green:0.30 blue:0.34 alpha:1.0];
    _eyeMat = [SCNMaterial material];
    _eyeMat.emission.contents = [NSColor colorWithCalibratedRed:0.95 green:0.95 blue:0.75 alpha:1.0];
    _noseMat = [SCNMaterial material];
    _noseMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.90 green:0.55 blue:0.55 alpha:1.0];
    // Ensure Z-buffer depth testing for all materials
    for (SCNMaterial *m in @[_furMat, _furLightMat, _eyeMat, _noseMat]) {
        m.readsFromDepthBuffer = YES;
        m.writesToDepthBuffer = YES;
        m.doubleSided = NO;
        m.transparency = 1.0;
        m.blendMode = SCNBlendModeAlpha;
        m.lightingModelName = SCNLightingModelPhysicallyBased;
        m.metalness.contents = @0.0;
        m.roughness.contents = @0.8;
    }

    // Size references
    CGFloat W = _catSize.width;
    CGFloat H = _catSize.height;

    // Body as a softly chamfered box (thickness along Z)
    SCNBox *bodyGeom = [SCNBox boxWithWidth:W*0.62 height:H*0.48 length:MAX(10.0, W*0.25) chamferRadius:H*0.10];
    bodyGeom.firstMaterial = _furMat;
    SCNNode *bodyNode = [SCNNode nodeWithGeometry:bodyGeom];
    bodyNode.position = SCNVector3Make(0, 0, 0);
    [_catModel addChildNode:bodyNode];

    // Head (sphere)
    SCNSphere *headGeom = [SCNSphere sphereWithRadius:H*0.22];
    headGeom.firstMaterial = _furLightMat;
    SCNNode *headNode = [SCNNode nodeWithGeometry:headGeom];
    headNode.position = SCNVector3Make(W*0.62*0.5 + W*0.18, H*0.06, 0);
    [_catModel addChildNode:headNode];

    // Ears (pyramids)
    SCNPyramid *earGeom = [SCNPyramid pyramidWithWidth:H*0.14 height:H*0.20 length:MAX(6.0, W*0.10)];
    earGeom.firstMaterial = _furMat;
    SCNNode *earL = [SCNNode nodeWithGeometry:earGeom];
    earL.position = SCNVector3Make(headNode.position.x - H*0.10, headNode.position.y + H*0.22, 0);
    [_catModel addChildNode:earL];
    SCNNode *earR = [SCNNode nodeWithGeometry:earGeom];
    earR.position = SCNVector3Make(headNode.position.x + H*0.10, headNode.position.y + H*0.22, 0);
    [_catModel addChildNode:earR];

    // Eyes (small spheres slightly in front)
    SCNSphere *eyeGeom = [SCNSphere sphereWithRadius:MAX(1.5, H*0.18*0.5)];
    eyeGeom.firstMaterial = _eyeMat;
    SCNNode *eyeL = [SCNNode nodeWithGeometry:eyeGeom];
    eyeL.position = SCNVector3Make(headNode.position.x - H*0.20, headNode.position.y + H*0.15, H*0.10);
    [_catModel addChildNode:eyeL];
    SCNNode *eyeR = [SCNNode nodeWithGeometry:eyeGeom];
    eyeR.position = SCNVector3Make(headNode.position.x + H*0.20, headNode.position.y + H*0.15, H*0.10);
    [_catModel addChildNode:eyeR];

    // Nose (small sphere)
    SCNSphere *noseGeom = [SCNSphere sphereWithRadius:MAX(1.0, H*0.08)];
    noseGeom.firstMaterial = _noseMat;
    SCNNode *noseNode = [SCNNode nodeWithGeometry:noseGeom];
    noseNode.position = SCNVector3Make(headNode.position.x, headNode.position.y - H*0.05, H*0.15);
    [_catModel addChildNode:noseNode];

    // Legs (cylinders)
    CGFloat legH = H*0.16;
    CGFloat legR = MAX(2.0, W*0.08*0.5);
    SCNCylinder *legGeom = [SCNCylinder cylinderWithRadius:legR height:legH];
    legGeom.firstMaterial = _furMat;
    _backLegNode = [SCNNode nodeWithGeometry:legGeom];
    _backLegNode.position = SCNVector3Make(-W*0.62*0.25, -H*0.30, 0);
    [_catModel addChildNode:_backLegNode];
    _frontLegNode = [SCNNode nodeWithGeometry:legGeom];
    _frontLegNode.position = SCNVector3Make(W*0.62*0.25, -H*0.30, 0);
    [_catModel addChildNode:_frontLegNode];

    // Tail (capsule), pivot at base to wag
    CGFloat tailLen = W*0.35;
    CGFloat tailR = MAX(2.0, H*0.06*0.5);
    SCNCapsule *tailGeom = [SCNCapsule capsuleWithCapRadius:tailR height:tailLen];
    tailGeom.firstMaterial = _furLightMat;
    _tailNode = [SCNNode nodeWithGeometry:tailGeom];
    _tailNode.position = SCNVector3Make(-W*0.62*0.5, H*0.10, 0);
    _tailNode.pivot = SCNMatrix4MakeTranslation(0, -tailLen/2.0, 0);
    [_catModel addChildNode:_tailNode];

    // Add a soft spotlight attached to the cat for a dynamic lighting effect
    _catSpotLightNode = [SCNNode node];
    _catSpotLightNode.light = [SCNLight light];
    _catSpotLightNode.light.type = SCNLightTypeSpot;
    _catSpotLightNode.light.color = [NSColor colorWithCalibratedRed:1.0 green:0.95 blue:0.90 alpha:1.0];
    _catSpotLightNode.light.intensity = 900;
    _catSpotLightNode.light.castsShadow = YES;
    _catSpotLightNode.light.spotInnerAngle = 22.0;
    _catSpotLightNode.light.spotOuterAngle = 48.0;
    _catSpotLightNode.light.attenuationStartDistance = 0.0;
    _catSpotLightNode.light.attenuationEndDistance = MAX(W, H);
    // Place the light slightly above and in front of the cat, aiming toward it (spotlights point along -Z)
    _catSpotLightNode.position = SCNVector3Make(0, H * 0.45, MAX(10.0, W * 0.35));
    _catSpotLightNode.eulerAngles = SCNVector3Make(0, 0, 0);
    [_catModel addChildNode:_catSpotLightNode];
}

- (void)startAnimation
{
    [super startAnimation];
    _tailPhase = 0.0;
    _zAnimStartTime = CFAbsoluteTimeGetCurrent();

    // Animate scale: 0.25 -> 0.75 over 3s, then back to 0.25 over 3s, repeat
    CGFloat baseScale = 0.25f; // must match setupSceneKit
    SCNAction *toBig = [SCNAction scaleTo:(baseScale * 3.0) duration:3.0];
    SCNAction *toSmall = [SCNAction scaleTo:(baseScale * 1.0) duration:3.0];
    toBig.timingMode = SCNActionTimingModeLinear;
    toSmall.timingMode = SCNActionTimingModeLinear;
    SCNAction *seq = [SCNAction sequence:@[toBig, toSmall]];
    SCNAction *repeat = [SCNAction repeatActionForever:seq];
    [_catModel removeAllActions];
    [_catModel runAction:repeat];

    // Cycle the cat spotlight color every 1 second
    if (_catSpotLightNode) {
        [_catSpotLightNode removeAllActions];
        __block NSInteger colorIndex = 0;
        NSArray<NSColor *> *colors = @[
            [NSColor colorWithCalibratedRed:1.0 green:0.95 blue:0.90 alpha:1.0], // warm
            [NSColor systemRedColor],
            [NSColor systemGreenColor],
            [NSColor systemBlueColor],
            [NSColor systemPurpleColor],
            [NSColor systemOrangeColor]
        ];
        SCNAction *step = [SCNAction runBlock:^(SCNNode *node){
            SCNLight *light = node.light;
            if (light) {
                NSColor *c = colors[colorIndex];
                NSColor *srgb = [c colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
                if (!srgb) {
                    srgb = [c colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SCNTransaction begin];
                    [SCNTransaction setAnimationDuration:0.25];
                    light.color = srgb ?: c;
                    [SCNTransaction commit];
                });
                colorIndex = (colorIndex + 1) % colors.count;
            }
        }];
        SCNAction *wait = [SCNAction waitForDuration:1.0];
        SCNAction *colorSeq = [SCNAction sequence:@[step, wait]];
        SCNAction *colorRepeat = [SCNAction repeatActionForever:colorSeq];
        [_catSpotLightNode runAction:colorRepeat];
    }

    // Change the cat's fur colors every 1 second
    if (_furMat && _furLightMat) {
        [_catModel removeActionForKey:@"FurColorCycle"];
        __block NSInteger furColorIndex = 0;
        NSArray<NSColor *> *furBaseColors = @[
            [NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:1.0], // red
            [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:0.0 alpha:1.0], // green
            [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:1.0 alpha:1.0], // blue
            [NSColor colorWithCalibratedRed:0.50 green:0.00 blue:0.50 alpha:1.0], // purple
            [NSColor colorWithCalibratedRed:0.93 green:0.51 blue:0.93 alpha:1.0]  // violet
        ];
        SCNAction *furStep = [SCNAction runBlock:^(__kindof SCNNode * _Nonnull node) {
            NSColor *base = furBaseColors[furColorIndex];
            NSColor *srgbBase = [base colorUsingColorSpace:[NSColorSpace sRGBColorSpace]] ?: [base colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] ?: base;
            NSColor *lighter = [srgbBase blendedColorWithFraction:0.35 ofColor:[NSColor whiteColor]] ?: srgbBase;

            dispatch_async(dispatch_get_main_queue(), ^{
                [SCNTransaction begin];
                [SCNTransaction setAnimationDuration:0.25];
                self->_furMat.diffuse.contents = srgbBase;
                self->_furLightMat.diffuse.contents = lighter;
                [SCNTransaction commit];
            });

            furColorIndex = (furColorIndex + 1) % furBaseColors.count;
        }];
        SCNAction *furWait = [SCNAction waitForDuration:1.0];
        SCNAction *furSeq = [SCNAction sequence:@[furStep, furWait]];
        SCNAction *furRepeat = [SCNAction repeatActionForever:furSeq];
        [_catModel runAction:furRepeat forKey:@"FurColorCycle"];
    }

    [self setNeedsDisplay:YES];
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)drawRect:(NSRect)rect
{
    // SceneKit renders the scene; no custom 2D drawing needed here.
}

- (void)animateOneFrame
{
    // Advance animation phase
    _tailPhase += 0.10; // Controls wag and bob speed
    if (_tailPhase > M_PI * 4) {
        _tailPhase -= M_PI * 4;
    }

    // Update position
    _catPos.x += _catVel.x;
    _catPos.y += _catVel.y;

    // Time-based Z motion: -depthRange -> +depthRange over 3s, then back over 3s
    NSTimeInterval zElapsed = CFAbsoluteTimeGetCurrent() - _zAnimStartTime;
    CGFloat zCycle = fmod(zElapsed, 6.0);
    if (zCycle <= 3.0) {
        CGFloat t = zCycle / 3.0; // 0..1
        _catZ = -_depthRange + (2.0 * _depthRange) * t;
    } else {
        CGFloat t = (zCycle - 3.0) / 3.0; // 0..1
        _catZ = +_depthRange - (2.0 * _depthRange) * t;
    }

    // Bounce off edges with margins based on size
    NSRect b = self.bounds;
    CGFloat modelScaleX = _catModel.scale.x;
    CGFloat modelScaleY = _catModel.scale.y;
    CGFloat effW = _catSize.width * modelScaleX;
    CGFloat effH = _catSize.height * modelScaleY;
    CGFloat bobAmp = (_catSize.height * 0.01) * modelScaleY; // Max vertical bob offset
    CGFloat marginX = MIN(effW * 0.55, MAX(0.0, NSWidth(b)/2.0 - 1.0));
    CGFloat marginY = MIN(effH * 0.55 + bobAmp, MAX(0.0, NSHeight(b)/2.0 - 1.0));
    CGFloat eps = 0.5f;

    if (_catPos.x <= NSMinX(b) + marginX) {
        _catPos.x = NSMinX(b) + marginX + eps;
        _catVel.x = fabs(_catVel.x);
        _facingRight = YES;
    } else if (_catPos.x >= NSMaxX(b) - marginX) {
        _catPos.x = NSMaxX(b) - marginX - eps;
        _catVel.x = -fabs(_catVel.x);
        _facingRight = NO;
    }

    if (_catPos.y <= NSMinY(b) + marginY) {
        _catPos.y = NSMinY(b) + marginY + eps;
        _catVel.y = fabs(_catVel.y);
    } else if (_catPos.y >= NSMaxY(b) - marginY) {
        _catPos.y = NSMaxY(b) - marginY - eps;
        _catVel.y = -fabs(_catVel.y);
    }

    // Ensure velocities don't collapse to zero (keep motion continuous)
    CGFloat minVX = MAX(1.0, _catSize.width / 120.0);
    CGFloat minVY = MAX(1.0, _catSize.height / 120.0);
    if (fabs(_catVel.x) < 0.01) {
        _catVel.x = _facingRight ? minVX : -minVX;
    }
    if (fabs(_catVel.y) < 0.01) {
        _catVel.y = (_catVel.y >= 0.0) ? minVY : -minVY;
    }

    // Update camera to map 1 world unit approximately to 1 point in view coordinates
    if (_cameraNode.camera.usesOrthographicProjection) {
        _cameraNode.camera.orthographicScale = NSHeight(self.bounds) / 2.0;
    }

    // Update 3D cat position (centered coordinate system) with visual bob
    CGFloat midX = NSMidX(self.bounds);
    CGFloat midY = NSMidY(self.bounds);
    CGFloat bob = sin(_tailPhase * 0.7) * (_catSize.height * 0.01) * modelScaleY;
    _catRoot.position = SCNVector3Make(_catPos.x - midX, (_catPos.y - midY) + bob, _catZ);

    // Face left/right by rotating around Y axis
    _catModel.eulerAngles = SCNVector3Make(0, _facingRight ? 0.0f : (float)M_PI, 0);

    // Animate legs and tail based on phase
    CGFloat H = _catSize.height;
    CGFloat legOffset = sin(_tailPhase * 2.0) * (H * 0.04);
    SCNVector3 backPos = _backLegNode.position;
    SCNVector3 frontPos = _frontLegNode.position;
    if (_facingRight) {
        backPos.y = -H*0.30 - legOffset;
        frontPos.y = -H*0.30 + legOffset;
    } else {
        backPos.y = -H*0.30 + legOffset;
        frontPos.y = -H*0.30 - legOffset;
    }
    _backLegNode.position = backPos;
    _frontLegNode.position = frontPos;

    // Tail wag (rotate around Z)
    _tailNode.eulerAngles = SCNVector3Make(0, 0, sin(_tailPhase * 2.0) * 0.35f);

    [_scnView setNeedsDisplay:YES];
    return;
}

- (BOOL)hasConfigureSheet
{
    return NO;
}

- (NSWindow*)configureSheet
{
    return nil;
}

@end

