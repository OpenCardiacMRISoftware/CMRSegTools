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
//  CMRTextROI.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 7/18/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <OsiriX/OSIROI.h>

@interface CMRTextROI : OSIROI
{
    NSString *_name;
    NSString *_text;
    N3Vector _position;
    
    NSCache    *stringTextureCache;
}

- (id)initWithText:(NSString *)test position:(N3Vector)position homeFloatVolumeData:(OSIFloatVolumeData *)floatVolumeData name:(NSString *)name;

@property (nonatomic, readonly, retain) NSString *text;
@property (nonatomic, readonly, assign) N3Vector position;

@end
