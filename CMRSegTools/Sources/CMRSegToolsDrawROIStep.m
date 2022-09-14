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
//  CMRSegToolsOuterContourStep.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 1/7/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRSegToolsDrawROIStep.h"
#import "CMRSegTools.h"
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/ROI.h>
#import <OsiriX/OSIROI.h>
#import <OsiriX/ViewerController.h>
#import <OsiriX/MyPoint.h>
#import "OsiriX+CMRSegTools.h"

const int CMRSegToolsDrawROIStepDontSetToolTag = 0xFFFFF;

@interface CMRSegToolsDrawROIStep()

@property (nonatomic, readwrite, assign, getter=isFinished) BOOL finished;

- (void)addROINotification:(NSNotification *)notification;

@end


@implementation CMRSegToolsDrawROIStep

@synthesize finished = _finished;

- (id)init
{
    return [self initWithROIName:@"CMRSegTools ROI" toolTag:11 color:[NSColor magentaColor]];
}

- (id)initWithROIName:(NSString *)roiName toolTag:(int)toolTag color:(NSColor *)color {
    return [self initWithROIName:roiName toolTag:toolTag color:color mode:CMRSegToolsDrawOneROIStepMode];
}

- (id)initWithROIName:(NSString *)roiName toolTag:(int)toolTag color:(NSColor *)color mode:(CMRSegToolsDrawROIStepMode)mode
{
    if ( (self = [super init])) {
        _roiName = [roiName retain];
        _color = [[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] retain];
        _toolTag = toolTag;
        _mode = mode;
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
    
    ViewerController *viewerController = [volumeWindow viewerController];
    if (_toolTag != CMRSegToolsDrawROIStepDontSetToolTag) {
        @try {
            [viewerController setROIToolTag:_toolTag];
        } @catch (...) {
            // ignore
        }
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addROINotification:) name:@"addROI" object:nil];
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
    RGBColor rgbColor = {[_color redComponent]*65535, [_color greenComponent]*65535, [_color blueComponent]*65535};
    
    [roi setName:_roiName];
    [roi setColor:rgbColor];
    [roi setOpacity:[_color alphaComponent]];
    
    if (_mode == CMRSegToolsDrawOneROIStepMode) {
        self.finished = YES;
        if ([self.delegate respondsToSelector:@selector(segToolsStepDidFinish:)]) {
            [self.delegate segToolsStepDidFinish:self];
        }

        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"addROI" object:nil];
    }
}


@end
