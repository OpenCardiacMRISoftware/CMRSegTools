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
//  CMRSegToolsBEASPointStep.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 1/4/15.
//  Copyright (c) 2015 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRSegToolsBEASPointStep.h"

#import <OsiriX/ViewerController.h>
//#import <OsiriX/ROI.h>
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/Notifications.h>

#import "CMRHistogramWindowController+BEASSegmenter.h"
#import "CMRSegTools.h"


@interface CMRSegToolsBEASPointStep ()

@property (nonatomic, readwrite, assign, getter=isFinished) BOOL finished;

- (void)mouseDownNotification:(NSNotification *)notification;

@end


@implementation CMRSegToolsBEASPointStep

@synthesize finished = _finished;
@synthesize histogramWindowController = _histogramWindowController;

- (void)dealloc
{
    _histogramWindowController = nil;
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


- (void)mouseDownNotification:(NSNotification *)notification
{
    if (_finished) {
        return;
    }

    NSPoint pixCoordinate = [[[notification userInfo] objectForKey:@"pixCoordinate"] pointValue];

    [self.histogramWindowController runBEAS:self constrainToPixPoints:@[[NSValue valueWithPoint:pixCoordinate]]];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixROIChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixRemoveROINotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixAddROINotification object:nil];

    self.finished = YES;
    if ([self.delegate respondsToSelector:@selector(segToolsStepDidFinish:)]) {
        [self.delegate segToolsStepDidFinish:self];
    }
}

@end
