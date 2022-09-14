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
//  CMRSegToolsGrowRegionStep.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 3/20/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRSegToolsGrowRegionStep.h"
#import "CMRSegTools.h"
#import "OsiriX+CMRSegTools.h"
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/ROI.h>
#import <OsiriX/OSIROI.h>
#import <OsiriX/ViewerController.h>
#import <OsiriX/MyPoint.h>

@interface CMRSegToolsGrowRegionStep()

@property (nonatomic, readwrite, assign, getter=isFinished) BOOL finished;

- (void)addROINotification:(NSNotification *)notification;
- (void)windowWillCloseNotification:(NSNotification *)notification;

@end


@implementation CMRSegToolsGrowRegionStep

@synthesize finished = _finished;

- (id)init
{
    return [self initWithROIName:@"CMRSegTools ROI" color:[NSColor magentaColor]];
}

- (id)initWithROIName:(NSString *)roiName color:(NSColor *)color
{
    if ( (self = [super init])) {
        _roiName = [roiName retain];
        _color = [[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] retain];
        _onlyOne = NO;
    }
    return self;
}

- (void)dealloc
{
    [_roiName release];
    [_color release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (BOOL)isFinished
{
    OSIVolumeWindow *volumeWindow = [self.delegate segToolsStepVolumeWindow:self];
    OSIROI *roi = [[volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:_roiName];
    
    return roi != nil || _finished;
}

- (void)start
{
    OSIVolumeWindow *volumeWindow = [self.delegate segToolsStepVolumeWindow:self];
    
    [[NSUserDefaults standardUserDefaults] setObject:_roiName forKey:@"growingRegionROIName"];
    
    ViewerController *viewerController = [volumeWindow viewerController];

// ViewerController implements the IBAction segmentationTest: but never declares it
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [viewerController performSelector:@selector(segmentationTest:) withObject:self];
#pragma clang diagnostic pop

    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addROINotification:) name:@"addROI" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillCloseNotification:) name:NSWindowWillCloseNotification object:nil];
}

- (void)cancel
{
    if (self.finished == NO) {
        self.finished = YES;
        if ([self.delegate respondsToSelector:@selector(segToolsStepDidCancel:)]) {
            [self.delegate segToolsStepDidCancel:self];
        }
    }
}

- (void)addROINotification:(NSNotification *)notification
{
    ROI *roi = [[notification userInfo] objectForKey:@"ROI"];
    
    if ([[roi name] isEqualToString:NSLocalizedString(@"Segmentation Preview", nil)]) {
        return;
    }
    
    RGBColor rgbColor = {[_color redComponent]*65535, [_color greenComponent]*65535, [_color blueComponent]*65535};
    
    [roi setName:_roiName];
    [roi setColor:rgbColor];
    [roi setOpacity:[_color alphaComponent]];
    
    if (_onlyOne) {
        self.finished = YES;
        if ([self.delegate respondsToSelector:@selector(segToolsStepDidFinish:)]) {
            [self.delegate segToolsStepDidFinish:self];
        }
    
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void)windowWillCloseNotification:(NSNotification *)notification
{
    if ([[[notification object] windowController] isKindOfClass:NSClassFromString(@"ITKSegmentation3DController")]) {
        self.finished = YES;
        if ([self.delegate respondsToSelector:@selector(segToolsStepDidFinish:)]) {
            [self.delegate segToolsStepDidFinish:self];
        }
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

@end
