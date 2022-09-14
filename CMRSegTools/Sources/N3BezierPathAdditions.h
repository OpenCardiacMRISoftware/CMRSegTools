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
//  N3BezierPathAdditions.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 7/19/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OsiriX/N3BezierPath.h>

@interface N3BezierPath (CMRSegToolsAdditions)

- (N3BezierPath *)bezierPathByClippingFromRelativePosition:(CGFloat)startPosition toRelativePotions:(CGFloat)endPosition;

- (N3BezierPath *)counterClockwiseBezierPathWithNormal:(N3Vector)normal;
- (N3BezierPath *)CMRBezierPathByReversing;
- (N3BezierPath *)bezierPathBySanitizingWithPrecision:(CGFloat)precision;

- (NSString *)lengthDescription;

@end

CFArrayRef N3BezierCoreCopySubpaths(N3BezierCoreRef bezierCore);

N3MutableBezierCoreRef N3BezierCoreCreateMutableByClipping(N3BezierCoreRef bezierCore, CGFloat startRelativePosition, CGFloat endRelativePosition);
CGFloat N3BezierCoreSignedAreaUsingNormal(N3BezierCoreRef bezierCore, N3Vector normal);

// here because they are buggy in OsiriX, can be taken out once OsiriX is fixed
N3BezierCoreRef N3BezierCoreCreateCopyByReversing(N3BezierCoreRef bezierCore);
N3MutableBezierCoreRef N3BezierCoreCreateMutableCopyByReversing(N3BezierCoreRef bezierCore);

// Sanitizing means removing any lineTos and close that don't actually move
N3BezierCoreRef N3BezierCoreCreateCopyBySanitizing(N3BezierCoreRef bezierCore, CGFloat precision);
N3MutableBezierCoreRef N3BezierCoreCreateMutableCopyBySanitizing(N3BezierCoreRef bezierCore, CGFloat precision);

N3MutableBezierCoreRef CMRBezierCoreCreateMutableOutlineWithNormal(N3BezierCoreRef bezierCore, CGFloat distance, CGFloat spacing, N3Vector projectionNormal);
N3MutableBezierCoreRef CMRBezierCoreCreateMutableOutline(N3BezierCoreRef bezierCore, CGFloat distance, CGFloat spacing, N3Vector initialNormal);
CFIndex CMRBezierCoreGetVectorInfo(N3BezierCoreRef bezierCore, CGFloat spacing, CGFloat startingDistance, N3Vector initialNormal,
                                   N3VectorArray vectors, N3VectorArray tangents, N3VectorArray normals, CFIndex numVectors);

