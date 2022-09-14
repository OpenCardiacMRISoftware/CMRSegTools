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
//  CMRHistogramWindowController+BEASSegmenter.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 11/28/12.
//  Copyright (c) 2012 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRHistogramWindowController.h"

@interface CMRHistogramWindowController (BEASSegmenter)

- (IBAction)runBEAS:(id)sender;

- (void)runBEAS:(id)sender constrainToPixPoints:(NSArray *)pixPoints;

- (void)runBEASOnMovieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex constrainToPixPoints:(NSArray *)pixPoints; // NSPoints stored as NSValues

@end
