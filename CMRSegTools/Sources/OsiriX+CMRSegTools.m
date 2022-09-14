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
//  OsiriX+CMRSegTools.m
//  CMRSegTools
//
//  Created by Alessandro Volz on 1/19/17.
//  Copyright © 2017 Spaltenstein Natural Image. All rights reserved.
//

#import "OsiriX+CMRSegTools.h"
#import "N3BezierPathAdditions.h"
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/DCMPix.h>
#import <OsiriX/pluginSDKAdditions.h>
#import <OsiriX/N3BezierCore.h>
#import <OsiriX/KBPopUpToolbarItem.h>

@implementation OSIROIManager (CMRSegTools)

- (NSArray *)CMRVisibleROIsWithName:(NSString *)name
{
    OSIVolumeWindow *volumeWindow = self->_volumeWindow;
    ViewerController *viewerController = [volumeWindow viewerController];
    DCMView *dcmView = [viewerController imageView];
    NSSet *dcmROIs = [NSSet setWithArray:[dcmView curRoiList]];
    NSMutableArray *visibleROIs = [NSMutableArray array];
    N3AffineTransform dicomToPixTransform = N3AffineTransformInvert([[dcmView curDCM] pixToDicomTransform]);
    
    for (OSIROI *roi in [self ROIsWithName:name]) {
        NSSet *osirixROIs = [roi osiriXROIs];
        if ([osirixROIs count] == 0) {
            if ([CMRSegTools isROI:roi onPixIndex:[dcmView curImage] dicomToPixTransform:dicomToPixTransform]) {
                [visibleROIs addObject:roi];
            }
        } else if ([osirixROIs intersectsSet:dcmROIs]) {
            [visibleROIs addObject:roi];
        }
    }
    return visibleROIs;
}

- (NSArray *)CMRROIsWithName:(NSString *)name movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex
{
    OSIVolumeWindow *volumeWindow = self->_volumeWindow;
    ViewerController *viewerController = [volumeWindow viewerController];
    DCMView *dcmView = [[viewerController imageViews] objectAtIndex:movieIndex];
    NSSet *dcmROIs = [NSSet setWithArray:[[dcmView dcmRoiList] objectAtIndex:pixIndex]];
    NSMutableArray *visibleROIs = [NSMutableArray array];
    N3AffineTransform dicomToPixTransform = N3AffineTransformInvert([[[dcmView dcmPixList] objectAtIndex:pixIndex] pixToDicomTransform]);
    
    for (OSIROI *roi in [self ROIsWithName:name]) {
        NSSet *osirixROIs = [roi osiriXROIs];
        if ([osirixROIs count] == 0) {
            if ([CMRSegTools isROI:roi onPixIndex:pixIndex dicomToPixTransform:dicomToPixTransform]) {
                [visibleROIs addObject:roi];
            }
            
        } else if ([osirixROIs intersectsSet:dcmROIs]) {
            [visibleROIs addObject:roi];
        }
    }
    return visibleROIs;
}

- (OSIROI *)CMRFirstVisibleROIWithName:(NSString *)name
{
    OSIVolumeWindow *volumeWindow = self->_volumeWindow;
    ViewerController *viewerController = [volumeWindow viewerController];
    DCMView *dcmView = [viewerController imageView];
    NSSet *dcmROIs = [NSSet setWithArray:[dcmView curRoiList]];
    
    N3AffineTransform dicomToPixTransform = N3AffineTransformInvert([[dcmView curDCM] pixToDicomTransform]);
    
    for (OSIROI *roi in [self ROIsWithName:name]) {
        NSSet *osirixROIs = [roi osiriXROIs];
        if ([osirixROIs count] == 0) {
            // so we now know that this is an real OSIROI, but is it on the right slice?
            if ([CMRSegTools isROI:roi onPixIndex:[dcmView curImage] dicomToPixTransform:dicomToPixTransform]) {
                return roi;
            }
        }
        if ([osirixROIs intersectsSet:dcmROIs]) {
            return roi;
        }
    }
    return nil;
}

- (OSIROI *)CMRFirstROIWithName:(NSString *)name movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex
{
    OSIVolumeWindow *volumeWindow = self->_volumeWindow;
    ViewerController *viewerController = [volumeWindow viewerController];
    DCMView *dcmView = [[viewerController imageViews] objectAtIndex:movieIndex];
    NSSet *dcmROIs = [NSSet setWithArray:[[dcmView dcmRoiList] objectAtIndex:pixIndex]];
    
    N3AffineTransform dicomToPixTransform = N3AffineTransformInvert([[[dcmView dcmPixList] objectAtIndex:pixIndex] pixToDicomTransform]);
    
    for (OSIROI *roi in [self ROIsWithName:name]) {
        NSSet *osirixROIs = [roi osiriXROIs];
        if ([osirixROIs count] == 0) {
            // so we now know that this is an real OSIROI, but is it on the right slice?
            if ([CMRSegTools isROI:roi onPixIndex:pixIndex dicomToPixTransform:dicomToPixTransform]) {
                return roi;
            }
        } else if ([osirixROIs intersectsSet:dcmROIs]) {
            return roi;
        }
    }
    return nil;
}

- (OSIROI *)CMRFirstVisibleROIWithNamePrefix:(NSString *)prefix
{
    OSIROI *roi = nil;
    
    for (NSString *roiName in [self ROINames]) {
        if ([roiName hasPrefix:prefix]) {
            roi = [self CMRFirstVisibleROIWithName:roiName];
            if (roi) {
                return roi;
            }
        }
    }
    return nil;
}

- (OSIROI *)CMRFirstROIWithNamePrefix:(NSString *)prefix movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex
{
    OSIROI *roi = nil;
    
    for (NSString *roiName in [self ROINames]) {
        if ([roiName hasPrefix:prefix]) {
            roi = [self CMRFirstROIWithName:roiName movieIndex:movieIndex pixIndex:pixIndex];
            if (roi) {
                return roi;
            }
        }
    }
    return nil;
}

- (OSIROI *)visibleEndocardialROI
{
    OSIROI *roi = [self CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Endocardium"];
    
    if ([roi isKindOfClass:[OSIPlanarPathROI class]]) {
        OSIPlanarPathROI* planarROI = (OSIPlanarPathROI*)roi;
        N3BezierPath *path = [planarROI bezierPath];
        N3Plane plane = [planarROI plane];
        CGFloat distance = (CGFloat)[[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRInsetEndocardium"];
        
        if (distance != 0 && [path length] != 0) {
            N3BezierPath *newPath = [path counterClockwiseBezierPathWithNormal:N3VectorInvert(plane.normal)];
            N3BezierCoreRef outlines = CMRBezierCoreCreateMutableOutlineWithNormal([newPath N3BezierCore], distance, 0.5, plane.normal);
            CFArrayRef cfSubPaths = N3BezierCoreCopySubpaths(outlines);
            newPath = [N3BezierPath bezierPathN3BezierCore:CFArrayGetValueAtIndex(cfSubPaths, 0)];
            N3BezierCoreRelease(outlines);
            CFRelease(cfSubPaths);
            return [planarROI planarPathROIWithPath:newPath];
        } else {
            return planarROI;
        }
    } else {
        if (roi != nil) {
            NSLog(@"expected CMRSegTools: Endocardium ROI to be an OSIPlanarPathROI");
        }
        return roi;
    }
}

- (OSIROI *)visibleEpicardialROI
{
    OSIROI *roi = [self CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium"];
    
    if ([roi isKindOfClass:[OSIPlanarPathROI class]]) {
        OSIPlanarPathROI* planarROI = (OSIPlanarPathROI*)roi;
        N3BezierPath *path = [planarROI bezierPath];
        N3Plane plane = [planarROI plane];
        CGFloat distance = (CGFloat)[[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRInsetEpicardium"];
        
        if (distance != 0 && [path length] != 0) {
            N3BezierPath *newPath = [path counterClockwiseBezierPathWithNormal:N3VectorInvert(plane.normal)];
            N3BezierCoreRef outlines = CMRBezierCoreCreateMutableOutlineWithNormal([newPath N3BezierCore], distance, 0.5, plane.normal);
            CFArrayRef cfSubPaths = N3BezierCoreCopySubpaths(outlines);
            newPath = [N3BezierPath bezierPathN3BezierCore:CFArrayGetValueAtIndex(cfSubPaths, 1)];
            N3BezierCoreRelease(outlines);
            CFRelease(cfSubPaths);
            return [planarROI planarPathROIWithPath:newPath];
        } else {
            return planarROI;
        }
    } else {
        if (roi != nil) {
            NSLog(@"expected CMRSegTools: Epicardium ROI to be an OSIPlanarPathROI");
        }
        return roi;
    }
}

- (OSIROI *)endocardialROIAtMovieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex
{
    OSIROI *roi = [self CMRFirstROIWithNamePrefix:@"CMRSegTools: Endocardium" movieIndex:movieIndex pixIndex:pixIndex];
    
    if ([roi isKindOfClass:[OSIPlanarPathROI class]]) {
        OSIPlanarPathROI* planarROI = (OSIPlanarPathROI*)roi;
        N3BezierPath *path = [planarROI bezierPath];
        N3Plane plane = [planarROI plane];
        CGFloat distance = (CGFloat)[[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRInsetEndocardium"];
        
        if (distance != 0 && [path length] != 0) {
            N3BezierPath *newPath = [path counterClockwiseBezierPathWithNormal:N3VectorInvert(plane.normal)];
            N3BezierCoreRef outlines = CMRBezierCoreCreateMutableOutlineWithNormal([newPath N3BezierCore], distance, 0.5, plane.normal);
            CFArrayRef cfSubPaths = N3BezierCoreCopySubpaths(outlines);
            newPath = [N3BezierPath bezierPathN3BezierCore:CFArrayGetValueAtIndex(cfSubPaths, 0)];
            N3BezierCoreRelease(outlines);
            CFRelease(cfSubPaths);
            return [planarROI planarPathROIWithPath:newPath];
        } else {
            return planarROI;
        }
    } else {
        if (roi != nil) {
            NSLog(@"expected CMRSegTools: Endocardium ROI to be an OSIPlanarPathROI");
        }
        return roi;
    }
}

- (OSIROI *)epicardialROIAtMovieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex
{
    OSIROI *roi = [self CMRFirstROIWithNamePrefix:@"CMRSegTools: Epicardium" movieIndex:movieIndex pixIndex:pixIndex];
    
    if ([roi isKindOfClass:[OSIPlanarPathROI class]]) {
        OSIPlanarPathROI* planarROI = (OSIPlanarPathROI*)roi;
        N3BezierPath *path = [planarROI bezierPath];
        N3Plane plane = [planarROI plane];
        CGFloat distance = (CGFloat)[[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRInsetEpicardium"];
        
        if (distance != 0 && [path length] != 0) {
            N3BezierPath *newPath = [path counterClockwiseBezierPathWithNormal:N3VectorInvert(plane.normal)];
            N3BezierCoreRef outlines = CMRBezierCoreCreateMutableOutlineWithNormal([newPath N3BezierCore], distance, 0.5, plane.normal);
            CFArrayRef cfSubPaths = N3BezierCoreCopySubpaths(outlines);
            newPath = [N3BezierPath bezierPathN3BezierCore:CFArrayGetValueAtIndex(cfSubPaths, 1)];
            N3BezierCoreRelease(outlines);
            CFRelease(cfSubPaths);
            return [planarROI planarPathROIWithPath:newPath];
        } else {
            return planarROI;
        }
    } else {
        if (roi != nil) {
            NSLog(@"expected CMRSegTools: Epicardium ROI to be an OSIPlanarPathROI");
        }
        return roi;
    }
}


@end


@implementation DCMView (CMRSegTools)

- (void)CMRSegToolsMouseMoved:(NSEvent *)event
{
    if (!event)
        return;
    
    if ([self is2DViewer]) {
        NSPoint mouseLocation = [self convertPoint:[event locationInWindow] fromView: nil];
        N3Vector mouseLocationVector = N3VectorMakeFromNSPoint(mouseLocation);
        N3AffineTransform viewToPixTransform = [self CMRSegToolsViewToPixTransform];
        N3AffineTransform viewToDicomTransform = N3AffineTransformConcat(viewToPixTransform, [self CMRSegToolsPixToDicomTransform]);
        N3Vector dicomCoordinate = N3VectorApplyTransform(mouseLocationVector, viewToDicomTransform);
        N3Vector normal = N3VectorNormalize(N3VectorApplyTransformToDirectionalVector(N3VectorMake(0.0, 0.0, 1.0), [self CMRSegToolsPixToDicomTransform]));
        NSPoint pixPoint = NSPointFromN3Vector(N3VectorApplyTransform(mouseLocationVector, viewToPixTransform));
        
        [[NSNotificationCenter defaultCenter] postNotificationName:CMRSegToolsMouseMovedNotification object:self
                                                          userInfo:@{@"event": event, @"dicomCoordinate": [NSValue valueWithN3Vector:dicomCoordinate],
                                                                     @"normal": [NSValue valueWithN3Vector:normal], @"pixCoordinate": [NSValue valueWithPoint:pixPoint]}];
    }
    [self CMRSegToolsMouseMoved:event];
}

- (void)CMRSegToolsMouseDown:(NSEvent *)event
{
    if ([self is2DViewer]) {
        NSPoint mouseLocation = [self convertPoint:[event locationInWindow] fromView: nil];
        N3Vector mouseLocationVector = N3VectorMakeFromNSPoint(mouseLocation);
        N3AffineTransform viewToPixTransform = [self CMRSegToolsViewToPixTransform];
        N3AffineTransform viewToDicomTransform = N3AffineTransformConcat(viewToPixTransform, [self CMRSegToolsPixToDicomTransform]);
        N3Vector dicomCoordinate = N3VectorApplyTransform(mouseLocationVector, viewToDicomTransform);
        N3Vector normal = N3VectorNormalize(N3VectorApplyTransformToDirectionalVector(N3VectorMake(0.0, 0.0, 1.0), [self CMRSegToolsPixToDicomTransform]));
        NSPoint pixPoint = NSPointFromN3Vector(N3VectorApplyTransform(mouseLocationVector, viewToPixTransform));
        
        [[NSNotificationCenter defaultCenter] postNotificationName:CMRSegToolsMouseDownNotification object:self
                                                          userInfo:@{@"event": event, @"dicomCoordinate": [NSValue valueWithN3Vector:dicomCoordinate],
                                                                     @"normal": [NSValue valueWithN3Vector:normal], @"pixCoordinate": [NSValue valueWithPoint:pixPoint]}];
    }
    [self CMRSegToolsMouseDown:event];
}

- (void)CMRSegToolsFlagsChanged:(NSEvent *)theEvent
{
    if ([self is2DViewer]) {
        if ([theEvent modifierFlags] & NSAlternateKeyMask) {
            [[CMRSegTools sharedInstance] setAnnotationHidden:YES];
        } else {
            [[CMRSegTools sharedInstance] setAnnotationHidden:NO];
        }
    }
    [self CMRSegToolsFlagsChanged:theEvent];
}

- (N3AffineTransform)CMRSegToolsViewToPixTransform
{
    // since there is no way to get matrix values directly for this transformation, we will figure out how the basis vectors get transformed, and contruct the matrix from these values
    N3AffineTransform viewToPixTransform;
    NSPoint orginBasis;
    NSPoint xBasis;
    NSPoint yBasis;
    
    orginBasis = [self ConvertFromNSView2GL:NSMakePoint(0, 0)];
    xBasis = [self ConvertFromNSView2GL:NSMakePoint(1, 0)];
    yBasis = [self ConvertFromNSView2GL:NSMakePoint(0, 1)];
    
    viewToPixTransform = N3AffineTransformIdentity;
    viewToPixTransform.m41 = orginBasis.x;
    viewToPixTransform.m42 = orginBasis.y;
    viewToPixTransform.m11 = xBasis.x - orginBasis.x;
    viewToPixTransform.m12 = xBasis.y - orginBasis.y;
    viewToPixTransform.m21 = yBasis.x - orginBasis.x;
    viewToPixTransform.m22 = yBasis.y - orginBasis.y;
    
    return viewToPixTransform;
}

- (N3AffineTransform)CMRSegToolsPixToDicomTransform // converts points in the DCMPix's coordinate space ("Slice Coordinates") into the DICOM space (patient space with mm units)
{
    N3AffineTransform pixToDicomTransform;
    double spacingX;
    double spacingY;
    //    double spacingZ;
    double orientation[9];
    
    memset(orientation, 0, sizeof(double) * 9);
    [[self curDCM] orientationDouble:orientation];
    spacingX = [self curDCM].pixelSpacingX;
    spacingY = [self curDCM].pixelSpacingY;
    //    spacingZ = pix.sliceInterval;
    
    pixToDicomTransform = N3AffineTransformIdentity;
    pixToDicomTransform.m41 = [self curDCM].originX;
    pixToDicomTransform.m42 = [self curDCM].originY;
    pixToDicomTransform.m43 = [self curDCM].originZ;
    pixToDicomTransform.m11 = orientation[0]*spacingX;
    pixToDicomTransform.m12 = orientation[1]*spacingX;
    pixToDicomTransform.m13 = orientation[2]*spacingX;
    pixToDicomTransform.m21 = orientation[3]*spacingY;
    pixToDicomTransform.m22 = orientation[4]*spacingY;
    pixToDicomTransform.m23 = orientation[5]*spacingY;
    pixToDicomTransform.m31 = orientation[6];
    pixToDicomTransform.m32 = orientation[7];
    pixToDicomTransform.m33 = orientation[8];
    
    return pixToDicomTransform;
}

@end


@implementation BrowserController (CMRSegTools)

static NSString * const CMRT1PreprocessingToolbarItemIdentifier = @"CMRT1Preprocessing";

- (NSArray *)CMRSegTools_toolbarAllowedItemIdentifiers:(NSToolbar *)t {
    return [[self CMRSegTools_toolbarAllowedItemIdentifiers:t] arrayByAddingObject:CMRT1PreprocessingToolbarItemIdentifier];
}

- (NSToolbarItem *)CMRSegTools_toolbar:(NSToolbar *)t itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    if ([itemIdentifier isEqualToString:CMRT1PreprocessingToolbarItemIdentifier]) {
        KBPopUpToolbarItem *ti = [[[KBPopUpToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
        ti.label = ti.paletteLabel = NSLocalizedString(@"CMR Filtering", nil);
        ti.image = [[[NSImage alloc] initWithContentsOfURL:[[NSBundle bundleForClass:CMRSegTools.class] URLForImageResource:@"CMRSegToolsIcon"]] autorelease];
        if (flag) {
            ti.target = [CMRSegTools sharedInstance];
            ti.action = @selector(CMRT1Preprocessing:);
            ti.menu = [[[NSMenu alloc] init] autorelease];
            ti.menu.delegate = [CMRSegTools sharedInstance];
        }
        return ti;
    }
    
    return [self CMRSegTools_toolbar:t itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:flag];
}

@end

@implementation OSIPlanarPathROI (CMRSegTools)

- (N3BezierPath *)bezierPath
{
    return _bezierPath;
}

- (N3Plane)plane
{
    return _plane;
}

- (instancetype)planarPathROIWithPath:(N3BezierPath *)path;
{
    OSIPlanarPathROI *newROI = [[OSIPlanarPathROI alloc] init];
    
    newROI->_homeFloatVolumeData = [[self homeFloatVolumeData] retain];
    newROI->_osiriXROI = [_osiriXROI retain];
    newROI->_plane = _plane;
    newROI->_bezierPath = [path mutableCopy];
    
    return newROI;
}

@end

@implementation OSIMaskROI (CMRSegTools)

- (OSIROIMask *)CMRSegToolsROIMaskForFloatVolumeData:(OSIFloatVolumeData *)floatVolume
{
    if (floatVolume == self.homeFloatVolumeData) {
        return _mask;
    } else {
        NSLog(@"OSIMaskROI returning empty mask because ROIMaskForFloatVolumeData is not fully implemented");
        return [OSIROIMask ROIMask];
    }
}

@end


@interface ViewerController (Hidden)

- (ROI *)isoContourROI:(ROI *)a numberOfPoints:(int)nof;

@end


@implementation OSIROIMask (CMRSegTools)

- (BOOL)CMRSegToolsIndexInMask:(OSIROIMaskIndex)index
{
    // since the runs are sorted, we can binary search
    NSUInteger runIndex = 0;
    NSUInteger runCount = 0;

    NSData *maskRunsData = [self maskRunsData];
    const OSIROIMaskRun *maskRuns = [maskRunsData bytes];
    runCount = [self maskRunCount];

    while (runCount) {
        NSUInteger middleIndex = runIndex + (runCount / 2);
        if (OSIROIMaskIndexInRun(index, maskRuns[middleIndex])) {
            return YES;
        }

        BOOL before = NO;
        if (index.z < maskRuns[middleIndex].depthIndex) {
            before = YES;
        } else if (index.z == maskRuns[middleIndex].depthIndex && index.y < maskRuns[middleIndex].heightIndex) {
            before = YES;
        } else if (index.z == maskRuns[middleIndex].depthIndex && index.y == maskRuns[middleIndex].heightIndex && index.x < maskRuns[middleIndex].widthRange.location) {
            before = YES;
        }

        if (before) {
            runCount /= 2;
        } else {
            runIndex = middleIndex + 1;
            runCount = (runCount - 1) / 2;
        }
    }

    return NO;
}

@end


@implementation ViewerController (CMRSegTools)

static NSString * const CMRSegToolsToolbarItemIdentifier = @"CMRSegTools";

- (ROI*) CMRSegToolsRoiMorphingBetween:(ROI*) a and:(ROI*) b ratio:(float) ratio
{
    if (a.type == tMesure && b.type == tMesure)
    {
        ROI* newMeasure = [self newROI: tMesure];

        [newMeasure addPoint:[ROI pointBetweenPoint:[a pointAtIndex:0] and:[b pointAtIndex:0] ratio:ratio]];
        [newMeasure addPoint:[ROI pointBetweenPoint:[a pointAtIndex:1] and:[b pointAtIndex:1] ratio:ratio]];

        [newMeasure setColor: [a rgbcolor]];
        [newMeasure setOpacity: [a opacity]];
        [newMeasure setThickness: [a thickness]];
        [newMeasure setName: [a name]];

        return newMeasure;
    }

    if( a.type == tMesure)
    {
        [a.points insertObject:[MyPoint point:[ROI pointBetweenPoint:[a pointAtIndex:0] and:[a pointAtIndex:1] ratio:0.5]] atIndex:1];
        a.type = tOPolygon;
    }

    if( b.type == tMesure)
    {
        [b.points insertObject:[MyPoint point:[ROI pointBetweenPoint:[b pointAtIndex:0] and:[b pointAtIndex:1] ratio:0.5]] atIndex:1];
        b.type = tOPolygon;
    }

    if( a.type == tROI || a.type == tOval)
    {
        NSMutableArray *points = a.points;
        if( a.type == tROI)
            a.isSpline = NO;

        a.type = tCPolygon;
        a.points = points;
    }

    if( b.type == tROI || b.type == tOval)
    {
        NSMutableArray *points = b.points;
        if( b.type == tROI)
            b.isSpline = NO;

        b.type = tCPolygon;
        b.points = points;
    }


	NSMutableArray	*aPts = [a points];
	NSMutableArray	*bPts = [b points];

	int maxPoints = MAX([aPts count], [bPts count]);
	maxPoints += maxPoints / 3;

	ROI* inputROI = a;

	a = [[a copy] autorelease];
	b = [[b copy] autorelease];

	a.isAliased = NO;
	b.isAliased = NO;

    // If the ROIs are brush ROIs, convert them into polygons, using a marching square isocontour
    // Otherwise update the points so they both have maxPoints number of points
	a = [self isoContourROI: a numberOfPoints: maxPoints];
	b = [self isoContourROI: b numberOfPoints: maxPoints];

	if( a == nil) return nil;
	if( b == nil) return nil;

	if( [[a points] count] != maxPoints || [[b points] count] != maxPoints)
	{
		NSLog( @"***** NoOfPoints !");
		return nil;
	}

	aPts = [a points];
	bPts = [b points];

    ROI* newROI = nil;
    if ( a.type == tOPolygon) {
        newROI = [self newROI: tOPolygon];
    }
    else
    {
        newROI = [self newROI: tCPolygon];
    }

    NSMutableArray *pts = [newROI points];
	int i;

	for( i = 0; i < [aPts count]; i++)
	{
		MyPoint	*aP = [aPts objectAtIndex: i];
		MyPoint	*bP = [bPts objectAtIndex: i];

		NSPoint newPt = [ROI pointBetweenPoint: [aP point] and: [bP point] ratio: ratio];

		[pts addObject: [MyPoint point: newPt]];
	}

	if( [inputROI type] == tPlain)
	{
#       pragma clang diagnostic push
#       pragma clang diagnostic ignored "-Wdeprecated-declarations"
        newROI = [self convertPolygonROItoBrush: newROI];
#       pragma clang diagnostic pop
	}

	[newROI setColor: [inputROI rgbcolor]];
	[newROI setOpacity: [inputROI opacity]];
	[newROI setThickness: [inputROI thickness]];
	[newROI setName: [inputROI name]];

	return newROI;
}

- (NSArray *)CMRSegTools_toolbarAllowedItemIdentifiers:(NSToolbar *)t {
    return [[self CMRSegTools_toolbarAllowedItemIdentifiers:t] arrayByAddingObject:CMRSegToolsToolbarItemIdentifier];
}

- (NSToolbarItem *)CMRSegTools_toolbar:(NSToolbar *)t itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    if ([itemIdentifier isEqualToString:CMRSegToolsToolbarItemIdentifier]) {
        NSToolbarItem *ti = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
        ti.label = ti.paletteLabel = NSLocalizedString(@"CMRSegTools", nil);
        ti.image = [[[NSImage alloc] initWithContentsOfURL:[[NSBundle bundleForClass:CMRSegTools.class] URLForImageResource:@"CMRSegToolsIcon"]] autorelease];
        ti.target = [CMRSegTools sharedInstance];
        ti.action = @selector(CMRSegTools:);
        return ti;
    }
    
    return [self CMRSegTools_toolbar:t itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:flag];
}

@end

@implementation PluginManagerController (CMRSegTools)

- (NSMenu *)CMRSegTools_ROIToolsMenu {
    return roisMenu;
}

- (NSMenu *)CMRSegTools_DatabaseMenu {
    return dbMenu;
}

@end



