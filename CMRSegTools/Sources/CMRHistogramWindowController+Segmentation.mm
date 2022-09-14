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
//  CMRHistogramWindowController+Segmentation.m
//  CMRSegTools
//
//  Created by Coralie Vandroux on 4/25/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRHistogramWindowController.h"
#import "hsu.h"
#import "gaussianMixtureModel.h"
#import "hmrfEm.h"

#import "CMRSegTools.h"
#import "OsiriX+CMRSegTools.h"
#import "CMRSegToolsDrawROIStep.h"
#import <OsiriX/ViewerController.h>
#import <OsiriX/DCMPix.h>
#import <OsiriX/DCMView.h>
#import <OsiriX/ROI.h>
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/OSIROIManager.h>
#import <OsiriX/OSIROI.h>
#import <OsiriX/Notifications.h>
#import <OsiriX/OSIROIMask.h>
#import <OsiriX/OSIMaskROI.h>
#import <OsiriX/OSIROIFloatPixelData.h>
#import <OsiriX/PluginFilter.h>
#import <OsiriX/DCM/DCMObject.h>
#import <OsiriX/DCM/DCMAttributeTag.h>
#import <OsiriX/DCM/DCMAttribute.h>

#import "HMRFalpha.h"


@interface CMRHistogramWindowController ()
- (void)_startStep:(CMRSegToolsStep *)step;
- (void)_setBrushToolToDraw;
- (void)removeROI:(NSString*)tool;
@end

@implementation CMRHistogramWindowController (Segmentation)

- (IBAction)popUp:(id)sender
{
    if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"Select ..."]) {
        [self SetMagicNameOnAllSlices:@"" MagicComment:@""];
        [self removeROI:@"noReference"];
    }
    else if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"xSD"]) {
        for (NSInteger i = 0; i<[popUpSegmentation numberOfItems]; i++) {
            if ([[popUpSegmentation itemAtIndex:i] state] == NSOnState)
                [[popUpSegmentation itemAtIndex:i] setState:NSOffState];
        }
        [[popUpSegmentation itemAtIndex:[popUpSegmentation indexOfSelectedItem]] setState:NSOnState];
        [popUpSegmentationProgressIndicator startAnimation:self];
        [self SetMagicNameOnAllSlices:@"" MagicComment:@""];
        [self removeROI:@"referenceSD"];
        OSIROI *referenceROI = [[self.volumeWindow ROIManager] firstVisibleROIWithNamePrefix:@"CMRSegTools: FWHMRegion"];
        if (referenceROI) {
            ROI *referenceBaseROI = [[referenceROI osiriXROIs]anyObject];
            [referenceBaseROI setName:@"CMRSegTools: Remote_stddev_5"];
        }
        else
        {
            [remoteMessage setHidden:NO];
            NSColor *remoteColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]];
            [self _startStep:[[[CMRSegToolsDrawROIStep alloc] initWithROIName:@"CMRSegTools: Remote_stddev_5" toolTag:11 color:[remoteColor colorWithAlphaComponent:.1]] autorelease]];
            [self _setBrushToolToDraw];
            [[[self.volumeWindow viewerController] window] makeKeyAndOrderFront:self];
        }
        [popUpSegmentationProgressIndicator stopAnimation:self];
    }
    else if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"xSD with sectors"])
    {
        for (NSInteger i = 0; i<[popUpSegmentation numberOfItems]; i++) {
            if ([[popUpSegmentation itemAtIndex:i] state] == NSOnState)
                [[popUpSegmentation itemAtIndex:i] setState:NSOffState];
        }
        [[popUpSegmentation itemAtIndex:[popUpSegmentation indexOfSelectedItem]] setState:NSOnState];
        [self removeROI:@"noReference"];

        OSIROI *outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];

        NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: Epicardium"];
        [newName appendString:@";xSD_Segment_1;xSD_Remote_stddev_5"];
        
        ROI* osirixROI = [[outsideROI osiriXROIs] anyObject];
        [osirixROI setName:newName];
    }
    else if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"FWHM with sectors"])
    {
        for (NSInteger i = 0; i<[popUpSegmentation numberOfItems]; i++) {
            if ([[popUpSegmentation itemAtIndex:i] state] == NSOnState)
                [[popUpSegmentation itemAtIndex:i] setState:NSOffState];
        }
        [[popUpSegmentation itemAtIndex:[popUpSegmentation indexOfSelectedItem]] setState:NSOnState];
        [self removeROI:@"noReference"];
        OSIROI *outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];

        NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: Epicardium"];
        [newName appendString:@";FWHM_Segment_1"];
        
        ROI* osirixROI = [[outsideROI osiriXROIs] anyObject];
        [osirixROI setName:newName];
    }
    else if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"FWHM Max"])
    {
        for (NSInteger i = 0; i<[popUpSegmentation numberOfItems]; i++) {
            if ([[popUpSegmentation itemAtIndex:i] state] == NSOnState)
                [[popUpSegmentation itemAtIndex:i] setState:NSOffState];
        }
        [[popUpSegmentation itemAtIndex:[popUpSegmentation indexOfSelectedItem]] setState:NSOnState];
        [popUpSegmentationProgressIndicator startAnimation:self];
        [self removeROI:@"noReference"];
        [self SetMagicNameOnAllSlices:@";FWHM Max" MagicComment:@""];
        ViewerController *viewerController = [self.volumeWindow viewerController];
        int curIndex = [[viewerController imageView]curImage];
        BOOL sliceIndex = [self slice];
        NSMutableArray  *roiSeriesList  = [viewerController roiList];
        for (int j=0; j<[roiSeriesList count]; j++) {
            [viewerController setImageIndex:j];
        }
        if (sliceIndex) {
            [viewerController setImageIndex:curIndex];
        }
        else
            [viewerController setImageIndex:(int)[roiSeriesList count]-curIndex-1];
        [popUpSegmentationProgressIndicator stopAnimation:self];
    }
    else if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"FWHM Region"])
    {
        for (NSInteger i = 0; i<[popUpSegmentation numberOfItems]; i++) {
            if ([[popUpSegmentation itemAtIndex:i] state] == NSOnState)
                [[popUpSegmentation itemAtIndex:i] setState:NSOffState];
        }
        [[popUpSegmentation itemAtIndex:[popUpSegmentation indexOfSelectedItem]] setState:NSOnState];
        [popUpSegmentationProgressIndicator startAnimation:self];
        [self SetMagicNameOnAllSlices:@"" MagicComment:@""];
        [self removeROI:@"referenceFWHM"];
        // to draw the region
        OSIROI *referenceROI = [[self.volumeWindow ROIManager] firstVisibleROIWithNamePrefix:@"CMRSegTools: Remote_stddev_"];
        if (referenceROI) {
            ROI *referenceBaseROI = [[referenceROI osiriXROIs]anyObject];
            [referenceBaseROI setName:@"CMRSegTools: FWHMRegion"];
        }
        else
        {
            [remoteMessage setHidden:NO];
            NSColor *remoteColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]];
            [self _startStep:[[[CMRSegToolsDrawROIStep alloc] initWithROIName:@"CMRSegTools: FWHMRegion" toolTag:11 color:[remoteColor colorWithAlphaComponent:.1]] autorelease]];
            [self _setBrushToolToDraw];
            [[[self.volumeWindow viewerController] window] makeKeyAndOrderFront:self];
        }
        
        [popUpSegmentationProgressIndicator stopAnimation:self];
    }
    else if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"FWHM Region 3D"])
    {
        for (NSInteger i = 0; i<[popUpSegmentation numberOfItems]; i++) {
            if ([[popUpSegmentation itemAtIndex:i] state] == NSOnState)
                [[popUpSegmentation itemAtIndex:i] setState:NSOffState];
        }
        [[popUpSegmentation itemAtIndex:[popUpSegmentation indexOfSelectedItem]] setState:NSOnState];
        [popUpSegmentationProgressIndicator startAnimation:self];
        [self SetMagicNameOnAllSlices:@"" MagicComment:@""];
        [self removeROI:@"noReference"];
        // to draw the region
        [remoteMessage setHidden:NO];
        NSColor *FWHMColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRFWHMColor"]];
        [self _startStep:[[[CMRSegToolsDrawROIStep alloc] initWithROIName:@"CMRSegTools: FWHM3D" toolTag:11 color:[FWHMColor colorWithAlphaComponent:.1]] autorelease]];
        [self _setBrushToolToDraw];
        [[[self.volumeWindow viewerController] window] makeKeyAndOrderFront:self];
        [popUpSegmentationProgressIndicator stopAnimation:self];
    }
    else if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"Hsu modified"])
    {
        for (NSInteger i = 0; i<[popUpSegmentation numberOfItems]; i++) {
            if ([[popUpSegmentation itemAtIndex:i] state] == NSOnState)
                [[popUpSegmentation itemAtIndex:i] setState:NSOffState];
        }
        [[popUpSegmentation itemAtIndex:[popUpSegmentation indexOfSelectedItem]] setState:NSOnState];
        [popUpSegmentationProgressIndicator startAnimation:self];
        [NRCheckbox setState:NSOffState];
        [self removeROI:@"noReference"];
        [self SetMagicNameOnAllSlices:@"" MagicComment:@""];
        
        ViewerController *viewerController = [self.volumeWindow viewerController];
        int curIndex = [[viewerController imageView]curImage];
        NSString        *dicomTag = @"0018,0023";
        NSArray         *pixList = [viewerController  pixList: 0];
        DCMPix          *curPix = [pixList objectAtIndex: curIndex];
        NSString        *file_path = [curPix sourceFile];
        DCMObject       *dcmObj = [DCMObject objectWithContentsOfFile:file_path decodingPixelData:NO];
        DCMAttributeTag *tag = [DCMAttributeTag tagWithName:dicomTag];
        if (!tag) tag = [DCMAttributeTag tagWithTagString:dicomTag];
        NSString        *val;
        DCMAttribute    *attr;
        attr = [dcmObj attributeForTag:tag];
        val = [[attr value] description];
        
        // if the sequence is coregistered
        if ([val isEqualToString:@"3D"])
        {
            gaussianMixtureModel *gmm = [[gaussianMixtureModel alloc] initWithVolumeWindow:self.volumeWindow];
            [gmm compute:@"gaussian"];
            hsu *Hsu = [[hsu alloc] initWithVolumeWindow:self.volumeWindow];
            [Hsu compute];
        }
        else
        {
            NSRunAlertPanel(@"Attention", @"This type of segmentation required a 3D aquisition", @"ok", nil, nil);
        }
        [popUpSegmentationProgressIndicator stopAnimation:self];
    }
    else if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"GMM : Rice & Gaussian"])
    {
        for (NSInteger i = 0; i<[popUpSegmentation numberOfItems]; i++) {
            if ([[popUpSegmentation itemAtIndex:i] state] == NSOnState)
                [[popUpSegmentation itemAtIndex:i] setState:NSOffState];
        }
        [[popUpSegmentation itemAtIndex:[popUpSegmentation indexOfSelectedItem]] setState:NSOnState];
        [popUpSegmentationProgressIndicator startAnimation:self];
        [self removeROI:@"noReference"];
        [self SetMagicNameOnAllSlices:@"" MagicComment:@""];
        gaussianMixtureModel *gmm = [[gaussianMixtureModel alloc] initWithVolumeWindow:self.volumeWindow];
        [gmm compute:@"rice"];
        [popUpSegmentationProgressIndicator stopAnimation:self];
    }
    else if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"HMRF EM"])
    {
        for (NSInteger i = 0; i<[popUpSegmentation numberOfItems]; i++) {
            if ([[popUpSegmentation itemAtIndex:i] state] == NSOnState)
                [[popUpSegmentation itemAtIndex:i] setState:NSOffState];
        }
        [NRCheckbox setState:NSOffState];
        [[popUpSegmentation itemAtIndex:[popUpSegmentation indexOfSelectedItem]] setState:NSOnState];
        [popUpSegmentationProgressIndicator startAnimation:self];
        [self removeROI:@"noReference"];
        [self SetMagicNameOnAllSlices:@"" MagicComment:@""];
        hmrfEm *HMRF_EM = [[hmrfEm alloc] initWithVolumeWindow:self.volumeWindow];
        [HMRF_EM compute];
        [HMRF_EM dealloc];
        [popUpSegmentationProgressIndicator stopAnimation:self];
    }
    //_______ADDED_BY_WAROMERO(28/07/2015)_______
    else if ([[popUpSegmentation titleOfSelectedItem] isEqualToString:@"HMRF (alpha version)"])
    {
        NSLog(@"[CMRSegTools] Executing HMRF (alpha version)...");
        
        for (NSInteger i = 0; i<[popUpSegmentation numberOfItems]; i++) {
            if ([[popUpSegmentation itemAtIndex:i] state] == NSOnState)
                [[popUpSegmentation itemAtIndex:i] setState:NSOffState];
        }
        [NRCheckbox setState:NSOffState];
        [[popUpSegmentation itemAtIndex:[popUpSegmentation indexOfSelectedItem]] setState:NSOnState];
        [popUpSegmentationProgressIndicator startAnimation:self];
        [self removeROI:@"noReference"];
        [self SetMagicNameOnAllSlices:@"" MagicComment:@""];
        
        HMRFalpha *hmrfAlpha = [[HMRFalpha alloc] initWithVolumeWindow:self.volumeWindow];
        [hmrfAlpha compute];
        
        [hmrfAlpha dealloc];
        [popUpSegmentationProgressIndicator stopAnimation:self];
    }
}

- (BOOL)slice
{
    ViewerController *viewerController = [self.volumeWindow viewerController];
    int curIndex = [[viewerController imageView]curImage];
    NSString        *dicomTag = @"0020,0013";
    NSArray         *pixList = [viewerController  pixList: 0];
    DCMPix          *curPix = [pixList objectAtIndex: curIndex];
    NSString        *file_path = [curPix sourceFile];
    DCMObject       *dcmObj = [DCMObject objectWithContentsOfFile:file_path decodingPixelData:NO];
    DCMAttributeTag *tag = [DCMAttributeTag tagWithName:dicomTag];
    if (!tag) tag = [DCMAttributeTag tagWithTagString:dicomTag];
    NSString        *val;
    DCMAttribute    *attr;
    attr = [dcmObj attributeForTag:tag];
    val = [[attr value] description];
    int valint=[[[NSString alloc] initWithString:val] intValue];
    BOOL rep;
    NSLog(@"val : %d, curindex : %d",valint,curIndex);
    if (curIndex+1==valint) {
        rep = true;
    }
    else
        rep = false;
    return rep;
}

- (void)SetMagicNameOnAllSlices:(NSString*)MagicName MagicComment:(NSString*)MagicComment
{
    // we look for the list of images
    ViewerController *viewerController = [self.volumeWindow viewerController];
    NSMutableArray  *roiSeriesList  = [viewerController roiList];
    
    // for all images
    for (int j=0; j<[roiSeriesList count]; j++) {
        // we look for the epicardium
        NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: j];
        if ([roiImageList count]>0) {
            int indexEpi;
            for (int k=0; k<[roiImageList count]; k++)
            {
                if ([[[roiImageList objectAtIndex:k] name] hasPrefix:@"CMRSegTools: Epicardium"])
                {
                    indexEpi = k;
                }
            }
            ROI *outsideROI = [roiImageList objectAtIndex:indexEpi];
            if(outsideROI)
            {
                // we change it's name
                NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: Epicardium"];
                [newName appendString:MagicName];
                [outsideROI setName:newName];
                [outsideROI setComments:MagicComment];
            }
        }
    }
}

@end
