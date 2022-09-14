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
//  CMRSegToolsPreferencePanel.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 10/15/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <PreferencePanes/PreferencePanes.h>


@interface CMRSegToolsPreferencePanel : NSPreferencePane <NSTableViewDataSource>
{
    NSArrayController *_filters;
    NSView *_preferenceView;
    NSTableView *_filtersTable;
}

//- (IBAction)updateColors:(id)sender;
//- (IBAction)dummyType:(id)sender;

@end

