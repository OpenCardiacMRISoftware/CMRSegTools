/*
--------------------------------------------------------------------------------
Copyright (C) 2022, CREATIS
Centre de Recherche en Acquisition et Traitement de l'Image pour la Santé
CNRS UMR 5220 - INSERM U1294 - Université Lyon 1 - INSA Lyon - 
Université Jean Monnet Saint-Etienne
FRANCE 

The utilisation of this source code is governed by a CeCILL licence which can be
found in the LICENCE.txt file.
--------------------------------------------------------------------------------
*/
//
//  CMRTextROI.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 7/18/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRTextROI.h"
#import <OsiriX/OSIROIMask.h>
#import <OsiriX/ViewerController.h>
#import <OsiriX/DCMView.h>
#import <OsiriX/StringTexture.h>

void gl_round_box(int mode, float minx, float miny, float maxx, float maxy, float rad, float factor);


N3AffineTransform CMRN3AffineTransformMakeFromOpenGLMatrixd(double *d); // d better be 16 elements long

@interface CMRTextROI ()

@property (nonatomic, readwrite, retain) NSString *name;
@property (nonatomic, readwrite, retain) NSString *text;
@property (nonatomic, readwrite, assign) N3Vector position;

@end


@implementation CMRTextROI

@synthesize name = _name;
@synthesize text = _text;
@synthesize position = _position;

- (id)initWithText:(NSString *)text position:(N3Vector)position homeFloatVolumeData:(OSIFloatVolumeData *)floatVolumeData name:(NSString *)name;
{
	if ( (self = [super init]) ) {
        [self setHomeFloatVolumeData:floatVolumeData];
        self.name = name;
        self.text = text;
        self.position = position;
	}
	return self;
}

- (void)dealloc
{
    self.name = nil;
    self.text = nil;
    
    [stringTextureCache release];
    stringTextureCache = nil;
    
    [super dealloc];
}


- (NSArray *)convexHull
{
    return @[[NSValue valueWithN3Vector:self.position]];
}

- (OSIROIMask *)ROIMaskForFloatVolumeData:(OSIFloatVolumeData *)floatVolume
{
    return [[[OSIROIMask alloc] init] autorelease];
}

- (void)drawSlab:(OSISlab)slab inCGLContext:(CGLContextObj)cgl_ctx pixelFormat:(CGLPixelFormatObj)pixelFormat dicomToPixTransform:(N3AffineTransform)dicomToPixTransform
{
    // this is a super lame hacky implementation, maybe I'll take the time to make it all clean and beatuful later...
    
    // we will base this off the existing DCMView string drawing, but first we need to get the DCMView....
    // heads up, this is going to be ugly!
    NSArray *viewers = [ViewerController getDisplayed2DViewers];
    DCMView *drawingDcmView = nil;
    for( ViewerController *v in viewers)
    {
        DCMView *dcmView = [v imageView];
        if ([[dcmView openGLContext] CGLContextObj] == cgl_ctx) {
            drawingDcmView = dcmView;
        }
    }
    
    if (drawingDcmView == nil) {
        return;
    }
    
    OSISlab transformedSlab = OSISlabApplyTransform(slab, dicomToPixTransform);
    N3Vector drawLocation = N3VectorApplyTransform(self.position, dicomToPixTransform);
    
    if (slab.thickness == 0) { // Older versions of OsiriX don;t implement thickness....
        if (N3VectorDistanceToPlane(drawLocation, transformedSlab.plane) > 0.5) {
            return;
        }
    } else {
        if (OSISlabContainsVector(slab, self.position) == NO) {
            return;
        }
    }
    

    if( self.text.length == 0) {
        return;
    }
    
    GLdouble modelViewMatrix[16];
    glGetDoublev(GL_MODELVIEW_MATRIX, modelViewMatrix);
    N3AffineTransform modelViewTransform = CMRN3AffineTransformMakeFromOpenGLMatrixd(modelViewMatrix);
    drawLocation = N3VectorApplyTransform(drawLocation, modelViewTransform);
    
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadIdentity();

    glScalef( 2.0f /([drawingDcmView drawingFrameRect].size.width), -2.0f / ([drawingDcmView drawingFrameRect].size.height), 1.0f);

    glGetDoublev(GL_MODELVIEW_MATRIX, modelViewMatrix);
    modelViewTransform = CMRN3AffineTransformMakeFromOpenGLMatrixd(modelViewMatrix);
    modelViewTransform = N3AffineTransformInvert(modelViewTransform);
    drawLocation = N3VectorApplyTransform(drawLocation, modelViewTransform);
    
    CGFloat sf = drawingDcmView.window.backingScaleFactor;
    NSSize stringSize = [self.text sizeWithAttributes:@{NSFontAttributeName: [NSFont fontWithName:@"Geneva" size:12]}];
    CGFloat halfDrawWidth = stringSize.width/2.0 + 2;
    CGFloat halfDrawHeight = stringSize.height/2.0 + 2;

    glColor4f(1.0f, 0.8f, 0.0f, 0.8f);
    gl_round_box(GL_POLYGON, drawLocation.x - halfDrawWidth*sf, drawLocation.y-halfDrawHeight*sf, drawLocation.x + (halfDrawWidth+2)*sf, drawLocation.y + halfDrawHeight*sf, 3, sf);

    StringTexture *sT = [self stringTextureForString:self.text backingScaleFactor:drawingDcmView.window.backingScaleFactor];
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
    glEnable(GL_POLYGON_SMOOTH);
    
    glEnable (GL_TEXTURE_RECTANGLE_EXT);
        
    glColor4f (0, 0, 0, 1.0f);
    [sT drawAtPoint: NSMakePoint( drawLocation.x-halfDrawWidth*sf, drawLocation.y-halfDrawHeight*sf)];
    
    glColor4f (1.0f, 1.0f, 1.0f, 1.0f);
    [sT drawAtPoint: NSMakePoint( drawLocation.x-(halfDrawWidth+1)*sf, drawLocation.y-(halfDrawHeight+1)*sf)];

    glDisable (GL_TEXTURE_RECTANGLE_EXT);
    glDisable(GL_POLYGON_SMOOTH);
    glDisable(GL_BLEND);
    
    glMatrixMode(GL_MODELVIEW);
    glPopMatrix();
}

// copied and modified from ROI.h
- (StringTexture*)stringTextureForString:(NSString*)str backingScaleFactor:(CGFloat)backingScaleFactor
{
    if( stringTextureCache == nil)
    {
        stringTextureCache = [[NSCache alloc] init];
        stringTextureCache.countLimit = 30;
    }
    
    StringTexture *sT = [stringTextureCache objectForKey: str];
    if( sT == nil)
    {
        NSMutableDictionary *attrib = [NSMutableDictionary dictionary];
        
        NSFont *fontGL = [NSFont fontWithName:@"Geneva" size:12];
        
        [attrib setObject: fontGL forKey:NSFontAttributeName];
        [attrib setObject: [NSColor whiteColor] forKey:NSForegroundColorAttributeName];
        
        
        sT = [[[StringTexture alloc] initWithString: str withAttributes: attrib] autorelease];
        [sT setAntiAliasing: YES];
        [sT genTextureWithBackingScaleFactor:backingScaleFactor];
        
        [stringTextureCache setObject: sT forKey: str];
    }
    
    return sT;
}

@end



N3AffineTransform CMRN3AffineTransformMakeFromOpenGLMatrixd(double *d) // d better be 16 elements long
{
    N3AffineTransform transform;
    transform.m11 = d[0];  transform.m12 = d[1];  transform.m13 = d[2];  transform.m14 = d[3];
    transform.m21 = d[4];  transform.m22 = d[5];  transform.m23 = d[6];  transform.m24 = d[7];
    transform.m31 = d[8];  transform.m32 = d[9];  transform.m33 = d[10]; transform.m34 = d[11];
    transform.m41 = d[12]; transform.m42 = d[13]; transform.m43 = d[14]; transform.m44 = d[15];
    return transform;
}















