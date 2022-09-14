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
//  Parser.h
//  CMRSegTools
//
//  Created by Coralie Vandroux on 4/30/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Parser : NSObject <NSXMLParserDelegate>
{
    NSXMLParser *parser;
    NSMutableString *currentProperty;
    NSMutableArray *currentKey;
    NSMutableArray *currentCount;
    NSMutableArray *Slices;
    
    NSMutableArray *HaveEpi;
    NSMutableArray *HaveEndo;
    NSMutableArray *HaveEnhanced;
    NSMutableArray *HaveRef;
    NSMutableArray *HaveNR;
    
    NSMutableArray *PointCoord;
    NSMutableArray *Points;
    NSMutableArray *Epi;
    NSMutableArray *Endo;
    NSMutableArray *Enhanced;
    NSMutableArray *Ref;
    NSMutableArray *NR;
    
    NSInteger nbPoints;
    long int subPixels;
    long int index;
    NSString *parent;
    NSString *StudyUid;
    NSString *SubpixelResolution;
}
@property (nonatomic, retain) NSMutableArray *Slices;
@property (nonatomic, retain) NSXMLParser *parser;
@property (nonatomic, retain) NSMutableArray *HaveEpi;
@property (nonatomic, retain) NSMutableArray *HaveEndo;
@property (nonatomic, retain) NSMutableArray *HaveEnhanced;
@property (nonatomic, retain) NSMutableArray *HaveRef;
@property (nonatomic, retain) NSMutableArray *HaveNR;
@property (nonatomic, retain) NSMutableArray *Epi;
@property (nonatomic, retain) NSMutableArray *Endo;
@property (nonatomic, retain) NSMutableArray *Enhanced;
@property (nonatomic, retain) NSMutableArray *Ref;
@property (nonatomic, retain) NSMutableArray *NR;
@property (nonatomic, retain) NSMutableArray *Points;
@property (nonatomic, retain) NSMutableArray *PointCoord;
@property (nonatomic, retain) NSMutableString *currentProperty;
@property (nonatomic, retain) NSString *StudyUid;
@property (nonatomic) long int subPixels;

@end
