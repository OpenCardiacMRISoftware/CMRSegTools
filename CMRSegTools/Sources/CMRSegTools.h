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
//  CMRSegTools.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 2/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OsiriX/PluginFilter.h>
#import <OsiriX/OSIROIManager.h>
#import <OsiriX/OSIPlanarPathROI.h>

extern NSString* const CMRSegToolsROIsDidUpdateNotification;
extern NSString* const CMRSegToolsMouseMovedNotification;
extern NSString* const CMRSegToolsMouseDownNotification;
extern NSString* const CMRSegToolsColorsDidUpdateNotification;

@interface CMRSegTools : PluginFilter <NSMenuDelegate> {
    
    BOOL  _annotationHidden;
    BOOL  _demoMode;
    
}

@property (nonatomic, readonly, assign, getter = isAnnotationHidden) BOOL annotationHidden;

- (long) filterImage:(NSString *) menuName;
+ (CMRSegTools *)sharedInstance;

- (void)updateCMRForVolumeWindow:(OSIVolumeWindow*)volumeWindow movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex; // update for this specific pix
- (void)updateCMRForVolumeWindow:(OSIVolumeWindow *)volumeWindow; //update everything in this volume window

- (void)setAnnotationHidden:(BOOL)annotationHidden;

+ (BOOL)isROI:(OSIROI *)roi onPixIndex:(NSInteger)pixIndex dicomToPixTransform:(N3AffineTransform)dicomToPixTransform;

- (IBAction)CMRT1Preprocessing:(id)sender;
- (IBAction)CMRSegTools:(id)sender;

+ (BOOL)parseRangeString:(NSString *)str prefix:(NSString *)prefix min:(float *)min max:(float *)max;
+ (NSString *)rangeStringWithPrefix:(NSString *)prefix min:(float)min max:(float)max;

@end



