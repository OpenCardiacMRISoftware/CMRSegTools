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
//  CMRSegToolsAngleWiperStep.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 7/23/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CMRSegToolsStep.h"

@class CMRSegToolsDrawROIStep;

enum _CMRSegToolsAngleWiperStepState {
    AngleWiperStepStartState = 0,
    AngleWiperStepStartFindKindState,
    AngleWiperStepEndState
};
typedef NSInteger CMRSegToolsAngleWiperStepState;


@interface CMRSegToolsAngleWiperStep : CMRSegToolsStep
{
    CMRSegToolsAngleWiperStepState state;
    BOOL _finished;
}


@end
