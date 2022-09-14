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
//  CMRSegToolsOuterContourStep.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 1/7/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRSegToolsStep.h"

extern const int CMRSegToolsDrawROIStepDontSetToolTag;

typedef enum : NSUInteger {
    CMRSegToolsDrawOneROIStepMode,
    CMRSegToolsDrawMoreROIStepMode,
} CMRSegToolsDrawROIStepMode;

@interface CMRSegToolsDrawROIStep : CMRSegToolsStep
{
    NSString *_roiName;
    NSColor *_color;
    int _toolTag;
    CMRSegToolsDrawROIStepMode _mode;
    BOOL _finished;
}

- (id)initWithROIName:(NSString *)roiName toolTag:(int)toolTag color:(NSColor *)color; // default mode is CMRSegToolsDrawOneROIStepMode
- (id)initWithROIName:(NSString *)roiName toolTag:(int)toolTag color:(NSColor *)color mode:(CMRSegToolsDrawROIStepMode)mode;

@end
