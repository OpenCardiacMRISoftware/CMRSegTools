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
//  CMRSegToolsStep.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 1/7/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CMRSegToolsStepDelegate;
@class OSIVolumeWindow;

@interface CMRSegToolsStep : NSObject
{
    id<CMRSegToolsStepDelegate> _delegate;
}

- (void)start;
- (void)cancel;

@property (nonatomic, readwrite, assign) id<CMRSegToolsStepDelegate>delegate;
@property (nonatomic, readonly, assign, getter=isFinished) BOOL finished;


@end


@protocol CMRSegToolsStepDelegate <NSObject>
@required
- (OSIVolumeWindow*)segToolsStepVolumeWindow:(CMRSegToolsStep*)step;
@optional
- (void)segToolsStepDidFinish:(CMRSegToolsStep*)step;
- (void)segToolsStepDidCancel:(CMRSegToolsStep*)step;
@end
