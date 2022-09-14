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
//  CMRHiResFloatVolumeData.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 7/16/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRSegToolsStep.h"
#import <OsiriX/OSIFloatVolumeData.h>
#import <OsiriX/OSIROIMask.h>

// This class is a bit of a hack that allows rois to make masks with a higher resolution than the backing data, this is used to emulate the totally unjustifiable results given by CMR42
// Things will probably crash if you actually try to access data using this class

@interface CMRHiResFloatVolumeData : OSIFloatVolumeData
{
    OSIFloatVolumeData *_referenceFloatVolumeData;
    
    NSUInteger _widthSubdivisions;
    NSUInteger _heightSubdivisions;
    NSUInteger _depthSubdivisions;
}

- (id)initWithFloatVolumeData:(OSIFloatVolumeData *)referenceFloatVolumeData widthSubdivisions:(NSUInteger)widthSubdivisions heightSubdivisions:(NSUInteger)heightSubdivisions depthSubdivisions:(NSUInteger)depthSubdivisions;


@property (nonatomic, readonly, retain) OSIFloatVolumeData *referenceFloatVolumeData;
@property (nonatomic, readonly, assign) NSUInteger widthSubdivisions;
@property (nonatomic, readonly, assign) NSUInteger heightSubdivisions;
@property (nonatomic, readonly, assign) NSUInteger depthSubdivisions;

@end


@interface OSIROIMask (CMRSegToolsAdditions)

- (OSIROIMask *)ROIMaskWithWidthSubdivisions:(NSUInteger)widthSubdivisions heightSubdivisions:(NSUInteger)heightSubdivisions depthSubdivisions:(NSUInteger)depthSubdivisions;

- (OSIROIMask *)initWithExtentWidth:(NSUInteger)width height:(NSUInteger)height depth:(NSUInteger)depth;

@end
