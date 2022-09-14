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
//  CMRSegToolsQuickDrawStep.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 3/20/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRSegToolsQuickDrawStep.h"
#import "CMRSegTools.h"
#import "CMRHistogramWindowController+BEASSegmenter.h"
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/OSIROIManager.h>
#import <OsiriX/OSIROI.h>
#import <OsiriX/OSIPathExtrusionROI.h>
#import <OsiriX/OSIFloatVolumeData.h>
#import <OsiriX/ViewerController.h>
#import <OsiriX/DCMView.h>
#import <OsiriX/ROI.h>
#import <OsiriX/N3BezierPath.h>
#import <OsiriX/Notifications.h>

@interface CMRSegToolsQuickDrawStep ()

@property (nonatomic, readwrite, assign, getter=isFinished) BOOL finished;

- (DCMView*)DCMView;
- (void)mouseMovedNotification:(NSNotification *)notification;
- (void)mouseDownNotification:(NSNotification *)notification;

@end

@implementation CMRSegToolsQuickDrawStep

@synthesize finished = _finished;
@synthesize draw6Sections;

- (id)init
{
    if ( (self = [super init]) ) {
        draw6Sections = YES;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)start
{
    OSIVolumeWindow *volumeWindow = [self.delegate segToolsStepVolumeWindow:self];
    ViewerController *viewerController = [volumeWindow viewerController];
    @try {
        [viewerController setROIToolTag:25];
    } @catch (...) {
        // ignore
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mouseDownNotification:) name:CMRSegToolsMouseDownNotification object:[self DCMView]];

}

- (BOOL)isFinished
{
    return _finished;
}

- (DCMView*)DCMView
{
    OSIVolumeWindow *volumeWindow = [self.delegate segToolsStepVolumeWindow:self];
    ViewerController *viewerController = [volumeWindow viewerController];

    return [viewerController imageView];
}


- (void)mouseDownNotification:(NSNotification *)notification;
{
    if (_finished) {
        return;
    }
    OSIVolumeWindow *volumeWindow = [self.delegate segToolsStepVolumeWindow:self];
    OSIROIManager *roiManager = [volumeWindow ROIManager];
    ViewerController *viewerController = [volumeWindow viewerController];

    N3Vector dicomCoordinate = [[[notification userInfo] objectForKey:@"dicomCoordinate"] N3VectorValue];
    NSPoint pixCoordinate = [[[notification userInfo] objectForKey:@"pixCoordinate"] pointValue];

    if (N3VectorIsZero(_epicardiumVector)) {
        _epicardiumVector = dicomCoordinate;
        _epicardiumPoint = pixCoordinate;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mouseMovedNotification:) name:CMRSegToolsMouseMovedNotification object:[self DCMView]];
    } else if (!N3VectorIsZero(_epicardiumVector) && N3VectorIsZero(_centerVector)) {
        _centerVector = dicomCoordinate;
        _centerPoint = pixCoordinate;
    } else if (!N3VectorIsZero(_centerVector) && N3VectorIsZero(_endocardiumLVRVVector)) {
        _endocardiumLVRVVector = dicomCoordinate;
        _endocardiumLVRVPoint = pixCoordinate;
        
        OSIROI *oldTempEpicardium = [roiManager firstROIWithName:@"CMRSegTools: tempEpicardium"];
        if (oldTempEpicardium) {
            [roiManager removeROI:oldTempEpicardium];
        }
        OSIROI *oldTempEndocardium = [roiManager firstROIWithName:@"CMRSegTools: tempEndocardium"];
        if (oldTempEndocardium) {
            [roiManager removeROI:oldTempEndocardium];
        }
        OSIROI *oldTempLVRV = [roiManager firstROIWithName:@"CMRSegTools: tempLV/RV"];
        if (oldTempLVRV) {
            [roiManager removeROI:oldTempLVRV];
        }

        ROI *epicardiumROI = [viewerController newROI:11];
        [epicardiumROI setName:@"CMRSegTools: Epicardium"];
        NSColor *epicardiumColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMREpicardiumColor"]];
        [epicardiumROI setNSColor:epicardiumColor];
        CGFloat epicardiumRadius = sqrt((_centerPoint.x-_epicardiumPoint.x)*(_centerPoint.x-_epicardiumPoint.x) + (_centerPoint.y-_epicardiumPoint.y)*(_centerPoint.y-_epicardiumPoint.y));
        [epicardiumROI addPoint:NSMakePoint(_centerPoint.x - epicardiumRadius, _centerPoint.y)];
        [epicardiumROI addPoint:NSMakePoint(_centerPoint.x, _centerPoint.y + epicardiumRadius)];
        [epicardiumROI addPoint:NSMakePoint(_centerPoint.x + epicardiumRadius, _centerPoint.y)];
        [epicardiumROI addPoint:NSMakePoint(_centerPoint.x, _centerPoint.y - epicardiumRadius)];
        
        [[[self DCMView] curRoiList] addObject:epicardiumROI];
        [[NSNotificationCenter defaultCenter] postNotificationName:OsirixAddROINotification object:self
                                                          userInfo:@{@"ROI": epicardiumROI, @"sliceNumber": [NSNumber numberWithShort:[[self DCMView] curImage]]}];
        
        ROI *endocardiumROI = [viewerController newROI:11];
        NSColor *endocardiumColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMREndocardiumColor"]];
        [endocardiumROI setNSColor:endocardiumColor];
        [endocardiumROI setName:@"CMRSegTools: Endocardium"];
        CGFloat endocardiumRadius = sqrt((_centerPoint.x-_endocardiumLVRVPoint.x)*(_centerPoint.x-_endocardiumLVRVPoint.x) + (_centerPoint.y-_endocardiumLVRVPoint.y)*(_centerPoint.y-_endocardiumLVRVPoint.y));
        [endocardiumROI addPoint:NSMakePoint(_centerPoint.x - endocardiumRadius, _centerPoint.y)];
        [endocardiumROI addPoint:NSMakePoint(_centerPoint.x, _centerPoint.y + endocardiumRadius)];
        [endocardiumROI addPoint:NSMakePoint(_centerPoint.x + endocardiumRadius, _centerPoint.y)];
        [endocardiumROI addPoint:NSMakePoint(_centerPoint.x, _centerPoint.y - endocardiumRadius)];
        
        [[[self DCMView] curRoiList] addObject:endocardiumROI];
        [[NSNotificationCenter defaultCenter] postNotificationName:OsirixAddROINotification object:self
                                                          userInfo:@{@"ROI": endocardiumROI, @"sliceNumber": [NSNumber numberWithShort:[[self DCMView] curImage]]}];
        
        ROI *LVRVROI = [viewerController newROI:5];
        NSColor *LVRVColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRLVRVColor"]];
        [LVRVROI setNSColor:LVRVColor];
        if (draw6Sections) {
            [LVRVROI setName:@"CMRSegTools: LV/RV"];
        } else {
            [LVRVROI setName:@"CMRSegTools: LV/RV;Number_of_sections_4"];
        }
        N3Vector centerPointVector = N3VectorMakeFromNSPoint(_centerPoint);
        N3Vector epicardiumPointVector = N3VectorMakeFromNSPoint(_epicardiumPoint);
        N3Vector endocardiumLVRVPoint = N3VectorMakeFromNSPoint(_endocardiumLVRVPoint);
        N3Vector lineToVector = N3VectorAdd(centerPointVector, N3VectorScalarMultiply(N3VectorNormalize(N3VectorSubtract(endocardiumLVRVPoint, centerPointVector)), N3VectorDistance(centerPointVector, epicardiumPointVector)*1.5));

        [LVRVROI addPoint:_centerPoint];
        [LVRVROI addPoint:NSPointFromN3Vector(lineToVector)];
        
        [[[self DCMView] curRoiList] addObject:LVRVROI];
        [[NSNotificationCenter defaultCenter] postNotificationName:OsirixAddROINotification object:self
                                                          userInfo:@{@"ROI": LVRVROI, @"sliceNumber": [NSNumber numberWithShort:[[self DCMView] curImage]]}];

        if ([self.delegate respondsToSelector:@selector(runBEAS:)]) {
            [self.delegate performSelector:@selector(runBEAS:) withObject:self];
        }
        
        self.finished = YES;

        if ([self.delegate respondsToSelector:@selector(segToolsStepDidFinish:)]) {
            [self.delegate segToolsStepDidFinish:self];
        }
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void)mouseMovedNotification:(NSNotification *)notification
{
    if (_finished) {
        return;
    }
    
    OSIVolumeWindow *volumeWindow = [self.delegate segToolsStepVolumeWindow:self];
    OSIROIManager *roiManager = [volumeWindow ROIManager];
    N3Vector dicomCoordinate = [[[notification userInfo] objectForKey:@"dicomCoordinate"] N3VectorValue];
    N3Vector normal = [[[notification userInfo] objectForKey:@"normal"] N3VectorValue];

    OSIROI *tempEndocardium = [roiManager firstROIWithName:@"CMRSegTools: tempEndocardium"];
    if (tempEndocardium) {
        [roiManager removeROI:tempEndocardium];
    }
    OSIROI *tempLVRV = [roiManager firstROIWithName:@"CMRSegTools: tempLV/RV"];
    if (tempLVRV) {
        [roiManager removeROI:tempLVRV];
    }
    
    if (!N3VectorIsZero(_epicardiumVector) && N3VectorIsZero(_centerVector)) {
        OSIROI *oldTempEpicardium = [roiManager firstROIWithName:@"CMRSegTools: tempEpicardium"];
        if (oldTempEpicardium) {
            [roiManager removeROI:oldTempEpicardium];
        }

        N3BezierPath *epiCircle = [N3BezierPath bezierPathCircleWithCenter:dicomCoordinate radius:N3VectorDistance(_epicardiumVector, dicomCoordinate) normal:normal];
        OSISlab slab = OSISlabMake(N3PlaneMake(dicomCoordinate, normal), 4);
        OSIFloatVolumeData *floatVolumeData = [volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
        OSIPathExtrusionROI *tempEpicardium = [[[OSIPathExtrusionROI alloc] initWith:epiCircle slab:slab homeFloatVolumeData:floatVolumeData name:@"CMRSegTools: tempEpicardium"] autorelease];
        NSColor *epicardiumColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMREpicardiumColor"]];
        [tempEpicardium setStrokeColor:epicardiumColor];
        [tempEpicardium setStrokeThickness:3];
        [roiManager addROI:tempEpicardium];
    }
    if (!N3VectorIsZero(_centerVector) && N3VectorIsZero(_endocardiumLVRVVector)) {
        OSIROI *oldTempEndocardium = [roiManager firstROIWithName:@"CMRSegTools: tempEndocardium"];
        if (oldTempEndocardium) {
            [roiManager removeROI:oldTempEndocardium];
        }
        OSIROI *oldTempLVRV = [roiManager firstROIWithName:@"CMRSegTools: tempLV/RV"];
        if (oldTempLVRV) {
            [roiManager removeROI:oldTempLVRV];
        }

        N3BezierPath *epiCircle = [N3BezierPath bezierPathCircleWithCenter:_centerVector radius:N3VectorDistance(_centerVector, dicomCoordinate) normal:normal];
        OSISlab slab = OSISlabMake(N3PlaneMake(dicomCoordinate, normal), 4);
        OSIFloatVolumeData *floatVolumeData = [volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
        OSIPathExtrusionROI *tempEndocardium = [[[OSIPathExtrusionROI alloc] initWith:epiCircle slab:slab homeFloatVolumeData:floatVolumeData name:@"CMRSegTools: tempEndocardium"] autorelease];
        NSColor *endocardiumColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMREndocardiumColor"]];
        [tempEndocardium setStrokeColor:endocardiumColor];
        [tempEndocardium setStrokeThickness:3];
        [roiManager addROI:tempEndocardium];
        
        N3MutableBezierPath *LVRVPath = [N3MutableBezierPath bezierPath];
        [LVRVPath moveToVector:_centerVector];
        [LVRVPath lineToVector:N3VectorAdd(_centerVector, N3VectorScalarMultiply(N3VectorNormalize(N3VectorSubtract(dicomCoordinate, _centerVector)), N3VectorDistance(_centerVector, _epicardiumVector)*1.5))];
        OSIPathExtrusionROI *tempLVRV = [[[OSIPathExtrusionROI alloc] initWith:LVRVPath slab:slab homeFloatVolumeData:floatVolumeData name:@"CMRSegTools: tempLV/RV"] autorelease];
        NSColor *LVRVColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRLVRVColor"]];
        [tempLVRV setStrokeColor:LVRVColor];
        [tempLVRV setStrokeThickness:3];
        [roiManager addROI:tempLVRV];
    }
}


@end
        
        
        
        
        
        
        
        
        
        
        
        
        
