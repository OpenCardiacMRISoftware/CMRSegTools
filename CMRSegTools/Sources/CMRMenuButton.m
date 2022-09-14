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
//  CMRMenuButton.m
//  CMRSegTools
//
//  Created by Alessandro Volz on 1/8/18.
//  Copyright © 2018 Creatis. All rights reserved.
//

#import "CMRMenuButton.h"

@implementation CMRMenuButton

//- (NSMenu *)menuForEvent:(NSEvent *)event {
//    if (event.type == NSLeftMouseDown)
//        return self.menu;
//    return nil;
//}

- (void)mouseDown:(NSEvent *)event {
    [self.menu popUpMenuPositioningItem:nil atLocation:[self convertPoint:event.locationInWindow fromView:nil] inView:self];
}

@end
