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
//  CMRT1Preprocessing.h
//  CMRSegTools
//
//  Created by Alessandro Volz on 5/4/16.
//  Copyright © 2016 volz.io. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CMRT1Preprocessing : NSViewController

+ (void)proceed:(NSDictionary *)fd;

@end

@interface CMRT1PreprocessingPic : NSObject {
    NSURL *_url;
    NSUInteger _frame;
}

@property (readonly, retain) NSURL *url;
@property (readonly) NSUInteger frame;

- (instancetype)initWithURL:(NSURL *)url frame:(NSUInteger)frame;

@end

@interface CMRT1Preprocessing (CPP)

- (NSArray<NSURL *> *)clone:(NSArray<CMRT1PreprocessingPic *> *)pix seriesDescription:(NSString *)seriesDescription seriesNumber:(NSUInteger)seriesNumber intoTmpDir:(NSURL *)tmpDir error:(NSError **)error;

@end
