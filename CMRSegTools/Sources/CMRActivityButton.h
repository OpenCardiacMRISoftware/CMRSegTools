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
//  CMRSTActivityButton.h
//  CMRSegTools
//
//  Created by Alessandro Volz on 7/7/15.
//  Copyright (c) 2015 Spaltenstein Natural Image. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CMRActivityButton : NSButton {
    NSProgressIndicator* _progressIndicator;
}

@property(assign) IBOutlet NSProgressIndicator* progressIndicator;


@end
