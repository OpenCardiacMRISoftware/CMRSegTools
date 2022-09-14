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
//  CMRHiResFloatVolumeData.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 7/16/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRHiResFloatVolumeData.h"

@interface CMRHiResFloatVolumeData ()

@property (nonatomic, readwrite, retain) OSIFloatVolumeData *referenceFloatVolumeData;
@property (nonatomic, readwrite, assign) NSUInteger widthSubdivisions;
@property (nonatomic, readwrite, assign) NSUInteger heightSubdivisions;
@property (nonatomic, readwrite, assign) NSUInteger depthSubdivisions;

@end

@implementation CMRHiResFloatVolumeData

@synthesize referenceFloatVolumeData = _referenceFloatVolumeData;
@synthesize widthSubdivisions = _widthSubdivisions;
@synthesize heightSubdivisions = _heightSubdivisions;
@synthesize depthSubdivisions = _depthSubdivisions;

- (id)initWithFloatVolumeData:(OSIFloatVolumeData *)referenceFloatVolumeData widthSubdivisions:(NSUInteger)widthSubdivisions heightSubdivisions:(NSUInteger)heightSubdivisions depthSubdivisions:(NSUInteger)depthSubdivisions
{
    assert(referenceFloatVolumeData);
    CPRVolumeDataInlineBuffer inlineBuffer;
    if ([referenceFloatVolumeData aquireInlineBuffer:&inlineBuffer]) {
        const float *floatBytes = CPRVolumeDataFloatBytes(&inlineBuffer);
        
        if ( (self = [super initWithFloatBytesNoCopy:floatBytes pixelsWide:[referenceFloatVolumeData pixelsWide]
                                          pixelsHigh:[referenceFloatVolumeData pixelsHigh]
                                          pixelsDeep:[referenceFloatVolumeData pixelsDeep]
                                     volumeTransform:[referenceFloatVolumeData volumeTransform]
                                    outOfBoundsValue:[referenceFloatVolumeData outOfBoundsValue]
                                        freeWhenDone:NO]) ) {
            

            self.referenceFloatVolumeData = referenceFloatVolumeData;
            
            self.widthSubdivisions = widthSubdivisions;
            self.heightSubdivisions = heightSubdivisions;
            self.depthSubdivisions = depthSubdivisions;
            
            _pixelsWide *= _widthSubdivisions;
            _pixelsHigh *= _heightSubdivisions;
            _pixelsDeep *= _depthSubdivisions;
            
            N3AffineTransform scaleTransform = N3AffineTransformMakeScale(widthSubdivisions, heightSubdivisions, depthSubdivisions);
            _volumeTransform = N3AffineTransformConcat([referenceFloatVolumeData volumeTransform], scaleTransform);
            
        }
    } else {
        [self autorelease];
        self = nil;
    }
    [referenceFloatVolumeData releaseInlineBuffer:&inlineBuffer];
    [self invalidateData]; // to make sure that we don't access the data
    return self;
}

- (void)dealloc
{
    self.referenceFloatVolumeData = nil;
    [super dealloc];
}

@end




@implementation OSIROIMask (CMRSegToolsAdditions)

- (OSIROIMask *)initWithExtentWidth:(NSUInteger)width height:(NSUInteger)height depth:(NSUInteger)depth
{
    NSUInteger y;
    NSUInteger z;
    NSMutableArray *runs = [NSMutableArray array];


    for (z = 0; z < depth; z++) {
        for (y = 0; y < height; y++) {
            OSIROIMaskRun maskRun = OSIROIMaskRunZero;
            maskRun.widthRange = NSMakeRange(0, width);
            maskRun.heightIndex = y;
            maskRun.depthIndex = z;
            
            [runs addObject:[NSValue valueWithOSIROIMaskRun:maskRun]];
        }
    }
    
    return [self initWithSortedMaskRuns:runs];
}


- (OSIROIMask *)ROIMaskWithWidthSubdivisions:(NSUInteger)widthSubdivisions heightSubdivisions:(NSUInteger)heightSubdivisions depthSubdivisions:(NSUInteger)depthSubdivisions
{
    NSMutableArray *subdividedRuns = [NSMutableArray array];
    NSUInteger y;
    NSUInteger z;
    
    NSArray *maskRuns = [self maskRuns];
    
    for (NSValue *maskRunValue in maskRuns) {
        OSIROIMaskRun maskRun = [maskRunValue OSIROIMaskRunValue];
                
        for (z = 0; z < depthSubdivisions; z++) {
            OSIROIMaskRun newDepthMaskRun = maskRun;
            newDepthMaskRun.depthIndex *= depthSubdivisions;
            newDepthMaskRun.depthIndex += z;
            
            for (y = 0; y < heightSubdivisions; y++) {
                OSIROIMaskRun newHeightMaskRun = newDepthMaskRun;
                newHeightMaskRun.heightIndex *= heightSubdivisions;
                newHeightMaskRun.heightIndex += y;
                
                newHeightMaskRun.widthRange.location *= widthSubdivisions;
                newHeightMaskRun.widthRange.length *= widthSubdivisions;
                
                [subdividedRuns addObject:[NSValue valueWithOSIROIMaskRun:newHeightMaskRun]];
            }
        }
    }
    
    return [[[OSIROIMask alloc] initWithMaskRuns:subdividedRuns] autorelease];
}

@end






