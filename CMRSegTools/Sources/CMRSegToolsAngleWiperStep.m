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
//  CMRSegToolsAngleWiperStep.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 7/23/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <OsiriX/Notifications.h>
#import <OsiriX/ViewerController.h>
#import <OsiriX/DCMView.h>
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/OSIROIManager.h>
#import <OsiriX/OSIROIMask.h>
#import <OsiriX/OSIROI.h>
#import <OsiriX/OSIFloatVolumeData.h>
#import <OsiriX/ROI.h>
#import <OsiriX/N3BezierPath.h>

#import "CMRSegToolsAngleWiperStep.h"
#import "CMRSegToolsDrawROIStep.h"
#import "CMRSegTools.h"
#import "OsiriX+CMRSegTools.h"

@interface CMRSegToolsAngleWiperStep ()

@property (nonatomic, readwrite, assign, getter=isFinished) BOOL finished;

- (void)addROINotification:(NSNotification *)notification;
- (void)removeROINotification:(NSNotification *)notification;
- (void)roiChangedROINotification:(NSNotification *)notification;


@end

@implementation CMRSegToolsAngleWiperStep

@synthesize finished = _finished;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)start
{
    OSIVolumeWindow *volumeWindow = [self.delegate segToolsStepVolumeWindow:self];
    @try {
        [[volumeWindow viewerController] setROIToolTag:tMesure];
    } @catch (...) {
        // ignore
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addROINotification:) name:OsirixAddROINotification object:nil];
}

- (void)addROINotification:(NSNotification *)notification
{
    // make sure that the roi that just got build it reasonable. 
    ROI *roi = [[notification userInfo] objectForKey:@"ROI"];
    
    if ([roi type] == tMesure) {
        if (state == AngleWiperStepStartState) {
            [roi setName:@"CMRSegTools: Infarct Start Angle"];
        } else {
            [roi setName:@"CMRSegTools: Infarct End Angle"];
        }
        NSColor *wiperColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRWiperColor"]];
        [roi setNSColor:wiperColor];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(roiChangedROINotification:) name:OsirixROIChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeROINotification:) name:OsirixRemoveROINotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixAddROINotification object:nil];
        state = AngleWiperStepStartFindKindState;
    } else {
        [self cancel];
    }
    
}


- (void)removeROINotification:(NSNotification *)notification;
{
    // OsiriX sends remore ROI notifications from inside the ROI's dealloc, which messes with the runtime, ignore these notifications
    NSArray *stackSymbols = [NSThread callStackSymbols];
    for (NSString *frame in stackSymbols) {
        if ([frame rangeOfString:@"[ROI dealloc]"].location != NSNotFound) {
            return;
        }
    }
    
    ROI *roi = [notification object];
    OSIVolumeWindow *volumeWindow = [self.delegate segToolsStepVolumeWindow:self];
    ViewerController *viewerController = [volumeWindow viewerController];
    
    BOOL knownROI = NO;
    BOOL startROI = NO;
    
    if ([[roi name] isEqualToString:@"CMRSegTools: Infarct Start Angle"]) {
        startROI = YES;
        knownROI = YES;
    } else if ([[roi name] isEqualToString:@"CMRSegTools: Infarct End Angle"]) {
        startROI = NO;
        knownROI = YES;
    }
    
    NSArray* ps = [roi points];
    if ([roi type] == tMesure && knownROI && ps.count) {
        BOOL noLength = YES;
        MyPoint* p = [ps objectAtIndex:0];
        for (int i = 1; noLength && i < ps.count; ++i) {
            MyPoint* q = [ps objectAtIndex:i];
            if (p.x != q.x || p.y != q.y)
                noLength = NO;
        }
        
        if (noLength) { // the user just clicked make the line from the centroid to the clicked point.
            NSPoint centerPoint = NSZeroPoint;
            OSIROI *LVRVLine = [[volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"];
            N3BezierPath *LVRVPath = [LVRVLine bezierPath];
            
            if ([LVRVPath elementCount]) {
                N3Vector moveTo = N3VectorZero;
                [LVRVPath elementAtIndex:0 control1:NULL control2:NULL endpoint:&moveTo];
                moveTo = N3VectorApplyTransform(moveTo, [[LVRVLine homeFloatVolumeData] volumeTransform]);
                centerPoint = NSMakePoint(moveTo.x, moveTo.y);
            } else {
                OSIROI *endocardiumROI = [[volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Endocardium"];
                OSIROIMask *roiMask;
                roiMask = [endocardiumROI ROIMaskForFloatVolumeData:[endocardiumROI homeFloatVolumeData]];
                NSData *maskData = [roiMask maskRunsData];
                NSInteger runCount = [maskData length]/sizeof(OSIROIMaskRun);
                const OSIROIMaskRun *runArray = [maskData bytes];
                NSUInteger i;
                CGFloat floatCount = 0;
                N3Vector centerOfMass = N3VectorZero;
                
                for (i = 0; i < runCount; i++) {
                    centerOfMass.x += ((CGFloat)runArray[i].widthRange.location+((CGFloat)runArray[i].widthRange.length/2.0)) * (CGFloat)runArray[i].widthRange.length;
                    centerOfMass.y += (CGFloat)runArray[i].heightIndex*(CGFloat)runArray[i].widthRange.length;
                    floatCount += runArray[i].widthRange.length;
                }
                
                centerOfMass.x /= floatCount;
                centerOfMass.y /= floatCount;
                centerPoint = NSMakePoint(centerOfMass.x, centerOfMass.y);
            }
            
            ROI *newROI = [viewerController newROI:5];
            NSColor *wiperColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRWiperColor"]];
            [newROI setNSColor:wiperColor];
            if (startROI) {
                [newROI setName:@"CMRSegTools: Infarct Start Angle"];
            } else {
                [newROI setName:@"CMRSegTools: Infarct End Angle"];
            }
            
            [newROI addPoint:centerPoint];
            [newROI addPoint:NSMakePoint(p.x, p.y)];
            
            [[[viewerController imageView] curRoiList] addObject:newROI];
            [[NSNotificationCenter defaultCenter] postNotificationName:OsirixAddROINotification object:self
                                                              userInfo:@{@"ROI": newROI, @"sliceNumber": [NSNumber numberWithShort:[[viewerController imageView] curImage]]}];
            
            if (startROI) {
                state = AngleWiperStepEndState;
                [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixROIChangeNotification object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixRemoveROINotification object:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addROINotification:) name:OsirixAddROINotification object:nil];
            } else {
                [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixROIChangeNotification object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixRemoveROINotification object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixAddROINotification object:nil];

                self.finished = YES;
                if ([self.delegate respondsToSelector:@selector(segToolsStepDidFinish:)]) {
                    [self.delegate segToolsStepDidFinish:self];
                }
            }
        } else {
            [self cancel];
        }
    } else {
        [self cancel];
    }
}

- (void)roiChangedROINotification:(NSNotification *)notification
{
    ROI *roi = [notification object];
    
    BOOL knownROI = NO;
    BOOL startROI = NO;

    if ([[roi name] isEqualToString:@"CMRSegTools: Infarct Start Angle"]) {
        startROI = YES;
        knownROI = YES;
    } else if ([[roi name] isEqualToString:@"CMRSegTools: Infarct End Angle"]) {
        startROI = NO;
        knownROI = YES;
    }
    
    NSArray* ps = [roi points];
    if ([roi type] == tMesure && knownROI && ps.count) {
        BOOL noLength = YES;
        MyPoint* p = [ps objectAtIndex:0];
        for (int i = 1; noLength && i < ps.count; ++i) {
            MyPoint* q = [ps objectAtIndex:i];
            if (p.x != q.x || p.y != q.y)
                noLength = NO;
        }
        
        if (noLength == NO) {
            if (startROI) {
                state = AngleWiperStepEndState;
                [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixROIChangeNotification object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixRemoveROINotification object:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addROINotification:) name:OsirixAddROINotification object:nil];
            } else {
                [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixROIChangeNotification object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixRemoveROINotification object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixAddROINotification object:nil];
                
                self.finished = YES;
                if ([self.delegate respondsToSelector:@selector(segToolsStepDidFinish:)]) {
                    [self.delegate segToolsStepDidFinish:self];
                }
            }
        }
    }
}

- (BOOL)isFinished
{
    return _finished;
}

- (void)cancel
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixROIChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixRemoveROINotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixAddROINotification object:nil];

    if (self.finished == NO) {
        self.finished = YES;
        if ([self.delegate respondsToSelector:@selector(segToolsStepDidCancel:)]) {
            [self.delegate segToolsStepDidCancel:self];
        }
    }
}


@end
