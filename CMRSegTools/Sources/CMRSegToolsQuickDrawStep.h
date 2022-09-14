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
//  CMRSegToolsQuickDrawStep.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 3/20/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRSegToolsStep.h"
#import <OsiriX/N3Geometry.h>

@interface CMRSegToolsQuickDrawStep : CMRSegToolsStep
{
    BOOL _finished;
    N3Vector _epicardiumVector;
    NSPoint _epicardiumPoint;
    N3Vector _centerVector;
    NSPoint _centerPoint;
    N3Vector _endocardiumLVRVVector;
    NSPoint _endocardiumLVRVPoint;
    
    BOOL draw6Sections;
}

- (id)init;

@property (nonatomic, readwrite, assign) BOOL draw6Sections;

@end
