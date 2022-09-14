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
//  OsiriX+CMRSegTools.h
//  CMRSegTools
//
//  Created by Alessandro Volz on 1/19/17.
//  Copyright © 2017 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRSegTools.h"
#import <OsiriX/OSIMaskROI.h>
#import <OsiriX/OSIROIMask.h>
#import <OsiriX/OSIROIManager.h>
#import <OsiriX/DCMView.h>
#import <OsiriX/ViewerController.h>
#import <OsiriX/PluginManagerController.h>
#import <OsiriX/BrowserController.h>


@interface OSIROIManager (CMRSegTools)

- (NSArray *)CMRVisibleROIsWithName:(NSString *)name;
- (NSArray *)CMRROIsWithName:(NSString *)name movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex;

- (OSIROI *)CMRFirstVisibleROIWithName:(NSString *)name;
- (OSIROI *)CMRFirstROIWithName:(NSString *)name movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex;

- (OSIROI *)CMRFirstVisibleROIWithNamePrefix:(NSString *)prefix;
- (OSIROI *)CMRFirstROIWithNamePrefix:(NSString *)prefix movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex;

- (OSIROI *)visibleEndocardialROI;
- (OSIROI *)visibleEpicardialROI;

- (OSIROI *)endocardialROIAtMovieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex;
- (OSIROI *)epicardialROIAtMovieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex;

@end


@interface OSIMaskROI (CMRSegTools)

- (OSIROIMask *)CMRSegToolsROIMaskForFloatVolumeData:(OSIFloatVolumeData *)floatVolume;

@end

@interface OSIROIMask (CMRSegTools)

- (BOOL)CMRSegToolsIndexInMask:(OSIROIMaskIndex)index;

@end

@interface DCMView (CMRSegTools)

- (void)CMRSegToolsMouseMoved:(NSEvent *)event;
- (void)CMRSegToolsMouseDown:(NSEvent *)event;
- (N3AffineTransform)CMRSegToolsViewToPixTransform;
- (N3AffineTransform)CMRSegToolsPixToDicomTransform;

- (void)CMRSegToolsFlagsChanged:(NSEvent *)theEvent;

@end

@interface ViewerController (CMRSegTools)

- (ROI *)CMRSegToolsRoiMorphingBetween:(ROI *)a and:(ROI *)b ratio:(float) ratio;

- (NSArray *)CMRSegTools_toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
- (NSToolbarItem *)CMRSegTools_toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;

@end

@interface PluginManagerController (CMRSegTools)

- (NSMenu *)CMRSegTools_ROIToolsMenu;
- (NSMenu *)CMRSegTools_DatabaseMenu;

@end

@interface BrowserController (CMRSegTools)

- (NSArray *)CMRSegTools_toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
- (NSToolbarItem *)CMRSegTools_toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;

@end

@interface OSIPlanarPathROI (CMRSegTools)

- (N3BezierPath *)bezierPath;
- (N3Plane)plane;
- (instancetype)planarPathROIWithPath:(N3BezierPath *)path;

@end
