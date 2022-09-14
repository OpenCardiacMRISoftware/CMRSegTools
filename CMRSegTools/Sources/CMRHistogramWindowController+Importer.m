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
//  CMRHistogramWindowController + Importer.m
//  CMRSegTools
//
//  Created by Coralie Vandroux on 4/30/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRHistogramWindowController.h"
#import "Parser.h"

#import "CMRSegTools.h"
#import <OsiriX/ViewerController.h>
#import <OsiriX/DCMPix.h>
#import <OsiriX/DCMView.h>
#import <OsiriX/ROI.h>
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/OSIROIManager.h>
#import <OsiriX/OSIROI.h>
#import <OsiriX/Notifications.h>

#import <OsiriX/DCM/DCMObject.h>
#import <OsiriX/DCM/DCMAttributeTag.h>
#import <OsiriX/DCM/DCMAttribute.h>

@implementation CMRHistogramWindowController (Importer)

- (IBAction)importROIs:(id)sender
{
    NSOpenPanel *tvarNSOpenPanelObj = [NSOpenPanel openPanel];
    NSArray* fileTypes = [ NSArray arrayWithObject:@"cvi42wsx" ];
    [tvarNSOpenPanelObj setAllowedFileTypes:fileTypes];
    NSInteger tvarNSInteger = [tvarNSOpenPanelObj runModal];
    if(tvarNSInteger == NSOKButton)
    {
        NSString * tvarFilename = [[tvarNSOpenPanelObj URL] path];
        long result;
                
        // create and init NSXMLParser object
        NSData *xmlData = [NSData dataWithContentsOfFile:tvarFilename];
        
        // create and init our delegate
        Parser *parserClass = [[Parser alloc] init];
        parserClass.parser = [[NSXMLParser alloc] initWithData:xmlData];
        [parserClass.parser setDelegate:parserClass];
        [parserClass.parser parse];
        
        long int sizeHaveEnhanced = [parserClass.HaveEnhanced count];
        if (sizeHaveEnhanced>0) {
            result = NSRunInformationalAlertPanel(@"import", @"There is a description of the segmented myocardium in this file, do you want to import it ?", @"Yes", @"No", nil);
        }
        
        
        if ([[parserClass.Slices objectAtIndex:0] isEqualToString:[self GetStudyInstanceUid]])
        {
            ViewerController *viewerController = [self.volumeWindow viewerController];
            
            NSInteger slices = [[viewerController pixList] count];
            NSString        *dicomTag = @"0002,0003";
            NSArray         *pixList = [viewerController  pixList: 0];
            
            NSInteger nbEndo = 0;
            NSInteger nbEpi = 0;
            NSInteger nbEnhanced = 0;
            NSInteger nbRef = 0;
            NSInteger nbNR = 0;
            //int j = [[viewerController imageView]curImage];
            for (int j=0; j<slices; j++)
            {
                DCMPix          *curPix = [pixList objectAtIndex: j];
                NSString        *file_path = [curPix sourceFile];                
                DCMObject       *dcmObj = [DCMObject objectWithContentsOfFile:file_path decodingPixelData:NO];                
                DCMAttributeTag *tag = [DCMAttributeTag tagWithName:dicomTag];
                if (!tag) tag = [DCMAttributeTag tagWithTagString:dicomTag];                
                NSString        *val;
                DCMAttribute    *attr;
                attr = [dcmObj attributeForTag:tag];
                val = [[attr value] description];
            
                long int indexEpi = [parserClass.HaveEpi indexOfObject:val];
                long int indexEndo = [parserClass.HaveEndo indexOfObject:val];
                long int indexEnhanced = [parserClass.HaveEnhanced indexOfObject:val];
                long int indexRef = [parserClass.HaveRef indexOfObject:val];
                long int indexNR = [parserClass.HaveNR indexOfObject:val];

                long int sizeHaveEpi = [parserClass.HaveEpi count];
                long int sizeHaveEndo = [parserClass.HaveEndo count];
                long int sizeHaveRef = [parserClass.HaveRef count];
                long int sizeHaveNR = [parserClass.HaveNR count];


                if (indexEpi<sizeHaveEpi)
                {
                    nbEpi ++;
                    NSArray *pointsEpi = [[NSArray alloc] initWithArray:[parserClass.Epi objectAtIndex:indexEpi]];
                    int subPix = (int)parserClass.subPixels;
                    [self drawContour:@"CMRSegTools: Epicardium" subPixel:subPix points:pointsEpi slice:j];
                }
                
                if (indexEndo<sizeHaveEndo)
                {
                    nbEndo ++;
                    NSArray *pointsEndo = [[NSArray alloc] initWithArray:[parserClass.Endo objectAtIndex:indexEndo]];
                    int subPix = (int)parserClass.subPixels;
                    [self drawContour:@"CMRSegTools: Endocardium" subPixel:subPix points:pointsEndo slice:j];
                }
                
                if (indexEnhanced<sizeHaveEnhanced)
                {
                    if (result==NSAlertDefaultReturn) {
                        nbEnhanced ++;
                        if ([importCheckbox state]) {
                            NSArray *pointsEnhanced = [[NSArray alloc] initWithArray:[parserClass.Enhanced objectAtIndex:indexEnhanced]];
                            int subPix = (int)parserClass.subPixels;
                            [self drawContour:@"CMRSegTools: MI by CMR42;YES" subPixel:subPix points:pointsEnhanced slice:j];
                        }
                        else {
                            NSArray *pointsEnhanced = [[NSArray alloc] initWithArray:[parserClass.Enhanced objectAtIndex:indexEnhanced]];
                            int subPix = (int)parserClass.subPixels;
                            [self drawContour:@"CMRSegTools: MI by CMR42;NO" subPixel:subPix points:pointsEnhanced slice:j];
                        }
                    }
                }
                if (indexNR<sizeHaveNR)
                {
                    if (result==NSAlertDefaultReturn) {
                        nbNR ++;
                        if ([importCheckbox state]) {
                            NSArray *pointsNR = [[NSArray alloc] initWithArray:[parserClass.NR objectAtIndex:indexNR]];
                            int subPix = (int)parserClass.subPixels;
                            [self drawContour:@"CMRSegTools: NR by CMR42;YES" subPixel:subPix points:pointsNR slice:j];
                        }
                        else {
                            NSArray *pointsNR = [[NSArray alloc] initWithArray:[parserClass.NR objectAtIndex:indexNR]];
                            int subPix = (int)parserClass.subPixels;
                            [self drawContour:@"CMRSegTools: NR by CMR42;NO" subPixel:subPix points:pointsNR slice:j];
                        }
                    }
                }

                if (indexRef<sizeHaveRef)
                {
                    nbRef ++;
                    NSArray *pointsRef = [[NSArray alloc] initWithArray:[parserClass.Ref objectAtIndex:indexRef]];
                    int subPix = (int)parserClass.subPixels;
                    [self drawContour:@"CMRSegTools: Remote_stddev_2" subPixel:subPix points:pointsRef slice:j];
                }
                                
            }
            if (nbEpi == 0 && nbEndo == 0)
                NSRunInformationalAlertPanel(@"Attention", @"Contours described in this file does not correspond to this type of images: no contour was displayed", @"OK", nil, nil);
        }
        else
            NSRunInformationalAlertPanel(@"Attention", @"Contours described in the file does not match the patient: no contour was displayed", @"OK", nil, nil);
        [parserClass.parser release];
    }
}

- (NSString*)GetStudyInstanceUid
{
    ViewerController *viewerController = [self.volumeWindow viewerController];
    NSArray         *pixList = [viewerController  pixList: 0];
    long            curSlice = [[viewerController imageView] curImage];
    DCMPix          *curPix = [pixList objectAtIndex: curSlice];
    NSString        *file_path = [curPix sourceFile];
    
    NSString        *dicomTag = @"0020,000D";
    
    DCMObject       *dcmObj = [DCMObject objectWithContentsOfFile:file_path decodingPixelData:NO];
    
    DCMAttributeTag *tag = [DCMAttributeTag tagWithName:dicomTag];
    if (!tag) tag = [DCMAttributeTag tagWithTagString:dicomTag];
    
    NSString        *val;
    DCMAttribute    *attr;
    
    {
        attr = [dcmObj attributeForTag:tag];
        
        val = [[attr value] description];
        
    }
    return val;
}

- (void)drawContour:(NSString*)nameContour subPixel:(int)subPixel points:(NSArray*)points slice:(int)slice
{
    ViewerController *viewerController = [self.volumeWindow viewerController];
    ROI *ROI = [viewerController newROI: tCPolygon];
    NSMutableArray*	roiPoints = [ROI points];
    NSInteger size = [points count];
    
    for ( int i=0;i<size-1;i++)
    {
        [roiPoints addObject: [viewerController newPoint: (float)[[[points objectAtIndex:i] objectAtIndex:0] intValue]/subPixel : (float)[[[points objectAtIndex:i] objectAtIndex:1] intValue]/subPixel]];
    }
    
    if ([nameContour isEqualToString:@"CMRSegTools: Epicardium"]) {
        [ROI setNSColor:[NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMREpicardiumColor"]]];
    }
    else if ([nameContour isEqualToString:@"CMRSegTools: Endocardium"])
        [ROI setNSColor:[NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMREndocardiumColor"]]];
    else if (([nameContour hasPrefix:@"CMRSegTools: MI by CMR42"]))
    {
        [ROI setColor:(RGBColor){65535,0,60000}];
        [ROI setOpacity:0.9];
    }
    else if (([nameContour hasPrefix:@"CMRSegTools: NR by CMR42"]))
    {
        [ROI setNSColor:[NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRNoReflowColor"]]];
        [ROI setOpacity:0.9];
    }
    else if ([nameContour isEqualToString:@"CMRSegTools: Remote_stddev_2"])
    {
        [ROI setNSColor:[NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]]];
        [ROI setOpacity:025];
    }
    
    [ROI setName:nameContour];
    [[[viewerController  roiList] objectAtIndex:slice] addObject:ROI];
    [[NSNotificationCenter defaultCenter] postNotificationName:OsirixAddROINotification object:self
                                                      userInfo:@{@"ROI": ROI, @"sliceNumber": [NSNumber numberWithShort:slice]}];
}

@end
