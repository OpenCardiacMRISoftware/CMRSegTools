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
//  CMRWindowController.h
//  CMRSegTools
//
//  Created by Alessandro Volz on 5/10/16.
//  Copyright © 2016 volz.io. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CMRWindowController : NSWindowController // is a renamed NIWindowController from NIMPR

+ (Class)NSWindowClass;
+ (NSRect)contentRect;
+ (NSUInteger)styleMask;
+ (NSWindow *)window;

@property (retain) NSViewController *contentViewController;

- (instancetype)initWithContentViewController:(NSViewController *)contentViewController NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithWindow:(NSWindow *)window NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)observeWindowWillClose:(NSNotification *)notification NS_REQUIRES_SUPER;

@end
