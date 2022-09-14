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
//  VetToolsImageButton
//  VetTools
//
//  Created by Alessandro Volz on 1/14/15.
//
//

#import <Cocoa/Cocoa.h>

@interface CMRImageButton : NSButton {
    NSTrackingArea* _trackingArea;
    BOOL _tracking;
}

@property(nonatomic, assign, getter=isTracking) BOOL tracking;

@end
