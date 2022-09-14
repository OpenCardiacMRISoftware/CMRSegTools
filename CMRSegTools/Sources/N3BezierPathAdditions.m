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
//  N3BezierPathAdditions.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 7/19/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "N3BezierPathAdditions.h"

@implementation N3BezierPath (CMRSegToolsAdditions)

- (N3BezierPath *)bezierPathByClippingFromRelativePosition:(CGFloat)startPosition toRelativePotions:(CGFloat)endPosition
{
    N3MutableBezierCoreRef clippedPath = N3BezierCoreCreateMutableByClipping([self N3BezierCore], startPosition, endPosition);
    N3BezierPath *returnedPath = [N3BezierPath bezierPathN3BezierCore:clippedPath];
    N3BezierCoreRelease(clippedPath);
    return returnedPath;
}

- (N3BezierPath *)counterClockwiseBezierPathWithNormal:(N3Vector)normal
{
    if (N3BezierCoreSignedAreaUsingNormal([self N3BezierCore], normal) >=0) {
        return [[self copy] autorelease];
    } else {
        return [self CMRBezierPathByReversing];
    }
}


// here because the reversing methods are buggy in OsiriX
- (N3BezierPath *)CMRBezierPathByReversing
{
    N3BezierCoreRef reversedBezierCore;
    N3MutableBezierPath *reversedBezierPath;
    
    reversedBezierCore = N3BezierCoreCreateCopyByReversing(_bezierCore);
    reversedBezierPath = [N3MutableBezierPath bezierPathN3BezierCore:reversedBezierCore];
    N3BezierCoreRelease(reversedBezierCore);
    return reversedBezierPath;
}

- (N3BezierPath *)bezierPathBySanitizingWithPrecision:(CGFloat)precision;
{
    N3BezierCoreRef sanitizedBezierCore;
    N3MutableBezierPath *sanitizedBezierPath;

    sanitizedBezierCore = N3BezierCoreCreateCopyBySanitizing(_bezierCore, precision);
    sanitizedBezierPath = [N3MutableBezierPath bezierPathN3BezierCore:sanitizedBezierCore];
    N3BezierCoreRelease(sanitizedBezierCore);
    return sanitizedBezierPath;
}

- (NSString *)lengthDescription
{
    NSMutableString *lengthDescription = [NSMutableString string];
    NSInteger i;
    N3Vector start;
    N3Vector end;
    N3BezierPathElement elementType;

    if ([self elementCount] < 2) {
        return @"no line segments";
    }

    [self elementAtIndex:0 control1:NULL control2:NULL endpoint:&start];
    [lengthDescription appendFormat:@"Move"];

    for (i = 1; i < self.elementCount; i++) {
        elementType = [self elementAtIndex:i control1:NULL control2:NULL endpoint:&end];

        switch (elementType) {
            case N3MoveToBezierCoreSegmentType:
                [lengthDescription appendFormat:@"\nMove"];
                break;
            case N3LineToBezierCoreSegmentType:
                [lengthDescription appendFormat:@"\nLine length: %13.8f", N3VectorDistance(start, end)];
                break;
            case N3CurveToBezierCoreSegmentType:
                [lengthDescription appendFormat:@"\nCurve length: %12.8f", N3VectorDistance(start, end)];
                break;
            case N3CloseBezierCoreSegmentType:
                [lengthDescription appendFormat:@"\nClose length: %12.8f", N3VectorDistance(start, end)];
                break;
            default:
                break;
        }

        start = end;
    }

    return lengthDescription;
}

@end

CFArrayRef N3BezierCoreCopySubpaths(N3BezierCoreRef bezierCore)
{
    CFMutableArrayRef subpaths = CFArrayCreateMutable(NULL, 0, &kN3BezierCoreArrayCallBacks);
    N3BezierCoreIteratorRef bezierCoreIterator;
    N3MutableBezierCoreRef subpath = NULL;
    N3BezierCoreSegmentType segmentType;
    N3Vector control1;
    N3Vector control2;
    N3Vector endpoint;

    bezierCoreIterator = N3BezierCoreIteratorCreateWithBezierCore(bezierCore);
    
    while (!N3BezierCoreIteratorIsAtEnd(bezierCoreIterator)) {
        segmentType = N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, &control1, &control2, &endpoint);
        
        if (segmentType == N3MoveToBezierCoreSegmentType) {
            subpath = N3BezierCoreCreateMutable();
            CFArrayAppendValue(subpaths, subpath);
            N3BezierCoreRelease(subpath);
        }
        
        N3BezierCoreAddSegment(subpath, segmentType, control1, control2, endpoint);
    }
    
    return subpaths;
}

N3MutableBezierCoreRef N3BezierCoreCreateMutableByClipping(N3BezierCoreRef bezierCore, CGFloat startRelativePosition, CGFloat endRelativePosition)
{
    N3BezierCoreRef flattenedBezierCore;
	N3BezierCoreIteratorRef bezierCoreIterator;
    N3MutableBezierCoreRef newBezierCore;
	N3BezierCoreSegmentType segmentType;
    CGFloat distanceTraveled = 0;
    CGFloat segmentLength = 0;
    CGFloat startPosition;
    CGFloat endPosition;
    CGFloat length;
    N3Vector endpoint;
    N3Vector prevEndpoint;
    N3Vector lerpPoint;
    bool needsMoveto = false;
    
    assert(startRelativePosition >= 0.0 && startRelativePosition <= 1.0);
    assert(endRelativePosition >= 0.0 && endRelativePosition <= 1.0);
    
    if (startRelativePosition == 0 && endRelativePosition == 1.0) {
        return N3BezierCoreCreateMutableCopy(bezierCore);
    }
    if (endRelativePosition == 0 && startRelativePosition == 1.0) {
        return N3BezierCoreCreateMutableCopy(bezierCore);
    }
    if (startRelativePosition == endRelativePosition) {
        return N3BezierCoreCreateMutableCopy(bezierCore);
    }
    if (N3BezierCoreSegmentCount(bezierCore) < 2) {
        return N3BezierCoreCreateMutableCopy(bezierCore);
    }
    
    if (N3BezierCoreHasCurve(bezierCore)) {
        flattenedBezierCore = N3BezierCoreCreateMutableCopy(bezierCore);
        N3BezierCoreFlatten((N3MutableBezierCoreRef)flattenedBezierCore, N3BezierDefaultFlatness);
    } else {
        flattenedBezierCore = N3BezierCoreRetain(bezierCore);
    }
    
    length = N3BezierCoreLength(flattenedBezierCore);
    startPosition = startRelativePosition * length;
    endPosition = endRelativePosition * length;
    
    bezierCoreIterator = N3BezierCoreIteratorCreateWithBezierCore(flattenedBezierCore);
    newBezierCore = N3BezierCoreCreateMutable();
    
    N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &prevEndpoint);
    while (!N3BezierCoreIteratorIsAtEnd(bezierCoreIterator)) { // find the start
        segmentType = N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &endpoint);
        if(segmentType == N3LineToBezierCoreSegmentType || segmentType == N3CloseBezierCoreSegmentType) {
            segmentLength = N3VectorDistance(endpoint, prevEndpoint);
            
            if (segmentLength && distanceTraveled + segmentLength > startPosition) {
                lerpPoint = N3VectorLerp(prevEndpoint, endpoint, (startPosition - distanceTraveled)/segmentLength);
                N3BezierCoreAddSegment(newBezierCore, N3MoveToBezierCoreSegmentType, N3VectorZero, N3VectorZero, lerpPoint);
                break;
            }
            distanceTraveled += segmentLength;
        }
        prevEndpoint = endpoint;
	}
    
    if (N3BezierCoreSegmentCount(newBezierCore) < 1 && startPosition < endPosition) { // for whatever reason an endpoint was not added, add the last point
        N3BezierCoreAddSegment(newBezierCore, N3MoveToBezierCoreSegmentType, N3VectorZero, N3VectorZero, endpoint);
    }
    
    if (startPosition > endPosition) { // go all the way around
        if (N3BezierCoreSegmentCount(newBezierCore) == 1) {
            N3BezierCoreAddSegment(newBezierCore, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, endpoint);
        }
        
        needsMoveto = true;
        while (!N3BezierCoreIteratorIsAtEnd(bezierCoreIterator)) { // find the start
            segmentType = N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &endpoint);
            if (N3BezierCoreIteratorIsAtEnd(bezierCoreIterator) && segmentType == N3CloseBezierCoreSegmentType) {
                N3BezierCoreAddSegment(newBezierCore, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, endpoint);
                needsMoveto = false;
            } else {
                N3BezierCoreAddSegment(newBezierCore, segmentType, N3VectorZero, N3VectorZero, endpoint);
            }
            prevEndpoint = endpoint;
        }
        
        N3BezierCoreIteratorRelease(bezierCoreIterator);
        bezierCoreIterator = N3BezierCoreIteratorCreateWithBezierCore(flattenedBezierCore);
        segmentType = N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &prevEndpoint);
        if (needsMoveto) {
            N3BezierCoreAddSegment(newBezierCore, N3MoveToBezierCoreSegmentType, N3VectorZero, N3VectorZero, prevEndpoint);
        }
        segmentType = N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &endpoint);
        segmentLength = N3VectorDistance(endpoint, prevEndpoint);
        distanceTraveled = 0;
    }

    if (segmentLength && distanceTraveled + segmentLength > endPosition) { // the end is on the active segment
        lerpPoint = N3VectorLerp(prevEndpoint, endpoint, (endPosition - distanceTraveled)/segmentLength);
        N3BezierCoreAddSegment(newBezierCore, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, lerpPoint);
    } else {
        N3BezierCoreAddSegment(newBezierCore, segmentType, N3VectorZero, N3VectorZero, endpoint); // if the end was not on the active segment, close out the segment
        while (!N3BezierCoreIteratorIsAtEnd(bezierCoreIterator)) { // find the end
            segmentType = N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &endpoint);
            if(segmentType == N3LineToBezierCoreSegmentType || segmentType == N3CloseBezierCoreSegmentType) {
                segmentLength = N3VectorDistance(endpoint, prevEndpoint);
                
                if (segmentLength && distanceTraveled + segmentLength > endPosition) {
                    lerpPoint = N3VectorLerp(prevEndpoint, endpoint, (endPosition - distanceTraveled)/segmentLength);
                    N3BezierCoreAddSegment(newBezierCore, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, lerpPoint);
                    break;
                } else {
                    N3BezierCoreAddSegment(newBezierCore, segmentType, N3VectorZero, N3VectorZero, endpoint);
                }
                distanceTraveled += segmentLength;
            } else {
                N3BezierCoreAddSegment(newBezierCore, segmentType, N3VectorZero, N3VectorZero, endpoint);
            }
            prevEndpoint = endpoint;
        }
    }

    N3BezierCoreRelease(flattenedBezierCore);
    N3BezierCoreIteratorRelease(bezierCoreIterator);
    return newBezierCore;
}


CGFloat N3BezierCoreSignedAreaUsingNormal(N3BezierCoreRef bezierCore, N3Vector normal)
{ // Yes I know this could be way faster by projecting in 2D tralala tralala
    CGFloat signedArea = 0;
    
    N3MutableBezierCoreRef flattenedBezierCore;
    N3BezierCoreRef subpathBezierCore;
    N3BezierCoreIteratorRef bezierCoreIterator;
    N3Vector prevEndpoint;
    N3Vector endPoint;
    N3BezierCoreSegmentType segmentType;
    CFArrayRef subPaths;
    CFIndex i;
    
    subPaths = N3BezierCoreCopySubpaths(bezierCore);
    normal = N3VectorNormalize(normal);

    for (i = 0; i < CFArrayGetCount(subPaths); i++) {
        subpathBezierCore = CFArrayGetValueAtIndex(subPaths, i);
        
        if(N3BezierCoreGetSegmentAtIndex(subpathBezierCore, N3BezierCoreSegmentCount(subpathBezierCore)-1, NULL, NULL, NULL) != N3CloseBezierCoreSegmentType) {
            continue;
        }
        
        if (N3BezierCoreHasCurve(subpathBezierCore)) {
            flattenedBezierCore = N3BezierCoreCreateMutableCopy(subpathBezierCore);
            N3BezierCoreFlatten((N3MutableBezierCoreRef)flattenedBezierCore, N3BezierDefaultFlatness);
        } else {
            flattenedBezierCore = N3BezierCoreRetain(subpathBezierCore);
        }

        bezierCoreIterator = N3BezierCoreIteratorCreateWithBezierCore(flattenedBezierCore);
        N3BezierCoreRelease(flattenedBezierCore);
        flattenedBezierCore = NULL;
        segmentType = N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &prevEndpoint);
        assert(segmentType == N3MoveToBezierCoreSegmentType);
        
        while (!N3BezierCoreIteratorIsAtEnd(bezierCoreIterator)) { // find the start
            N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &endPoint);
            
            signedArea += N3VectorDotProduct(N3VectorCrossProduct(prevEndpoint, endPoint), normal);
            
            prevEndpoint = endPoint;
        }
        
        N3BezierCoreIteratorRelease(bezierCoreIterator);
    }

    CFRelease(subPaths);
    
    return signedArea*0.5;
}

// reversing methods copied to the plugin because they are buggy in OsiriX

N3BezierCoreRef N3BezierCoreCreateCopyByReversing(N3BezierCoreRef bezierCore)
{
    return N3BezierCoreCreateMutableCopyByReversing(bezierCore);
}

N3MutableBezierCoreRef N3BezierCoreCreateMutableCopyByReversing(N3BezierCoreRef bezierCore)
{
    N3BezierCoreRandomAccessorRef bezierAccessor;
    N3MutableBezierCoreRef reversedBezier;
    bool needsClose;
    bool needsMove;
    long i = 0;
    N3BezierCoreSegmentType segmentType;
    N3Vector control1;
    N3Vector control2;
    N3Vector endpoint;
    N3BezierCoreSegmentType prevSegmentType;
    N3Vector prevControl1;
    N3Vector prevControl2;
    N3Vector prevEndpoint;
    
    bezierAccessor = N3BezierCoreRandomAccessorCreateWithBezierCore(bezierCore);
    reversedBezier = N3BezierCoreCreateMutable();
    
    // check empty bezierPath special case
    if (N3BezierCoreRandomAccessorSegmentCount(bezierAccessor) == 0) {
        N3BezierCoreRandomAccessorRelease(bezierAccessor);
        return reversedBezier;
    }
    
    // check for the special case of a bezier with just a moveto
    if (N3BezierCoreRandomAccessorSegmentCount(bezierAccessor) == 1) {
        segmentType = N3BezierCoreRandomAccessorGetSegmentAtIndex(bezierAccessor, i, &control1, &control2, &endpoint);
        assert(segmentType == N3MoveToBezierCoreSegmentType);
        N3BezierCoreAddSegment(reversedBezier, N3MoveToBezierCoreSegmentType, N3VectorZero, N3VectorZero, endpoint);
        N3BezierCoreRandomAccessorRelease(bezierAccessor);
        return reversedBezier;
    }
    
    needsClose = false;
    needsMove = true;
    
    prevSegmentType = N3BezierCoreRandomAccessorGetSegmentAtIndex(bezierAccessor, N3BezierCoreRandomAccessorSegmentCount(bezierAccessor) - 1, &prevControl1, &prevControl2, &prevEndpoint);
    
    for (i = N3BezierCoreRandomAccessorSegmentCount(bezierAccessor) - 2; i >= 0; i--) {
        segmentType = N3BezierCoreRandomAccessorGetSegmentAtIndex(bezierAccessor, i, &control1, &control2, &endpoint);
        
        if (needsMove && prevSegmentType != N3CloseBezierCoreSegmentType) {
            N3BezierCoreAddSegment(reversedBezier, N3MoveToBezierCoreSegmentType, N3VectorZero, N3VectorZero, prevEndpoint);
            needsMove = false;
        }
        
        switch (prevSegmentType) {
            case N3CloseBezierCoreSegmentType:
                needsClose = true;
                break;
            case N3LineToBezierCoreSegmentType:
                N3BezierCoreAddSegment(reversedBezier, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, endpoint);
                break;
            case N3CurveToBezierCoreSegmentType:
                N3BezierCoreAddSegment(reversedBezier, N3CurveToBezierCoreSegmentType, prevControl2, prevControl1, endpoint);
                break;
            case N3MoveToBezierCoreSegmentType:
                if (needsClose) {
                    N3BezierCoreAddSegment(reversedBezier, N3CloseBezierCoreSegmentType, N3VectorZero, N3VectorZero, N3VectorZero);
                }
                N3BezierCoreAddSegment(reversedBezier, N3MoveToBezierCoreSegmentType, N3VectorZero, N3VectorZero, endpoint);
                needsClose = false;
                needsMove = true;
                break;
            default:
                break;
        }
        
        prevSegmentType = segmentType;
        prevControl1 = control1;
        prevControl2 = control2;
        prevEndpoint = endpoint;
    }
    
    assert(prevSegmentType == N3MoveToBezierCoreSegmentType);
    
    N3BezierCoreRandomAccessorRelease(bezierAccessor);
    N3BezierCoreCheckDebug(reversedBezier);
    
    return reversedBezier;
}

// Sanitizing means removing any lineTos and close that don't actually move
N3BezierCoreRef N3BezierCoreCreateCopyBySanitizing(N3BezierCoreRef bezierCore, CGFloat precision)
{
    return N3BezierCoreCreateMutableCopyBySanitizing(bezierCore, precision);
}

N3MutableBezierCoreRef N3BezierCoreCreateMutableCopyBySanitizing(N3BezierCoreRef bezierCore, CGFloat precision)
{
    N3BezierCoreRandomAccessorRef bezierAccessor;
    N3MutableBezierCoreRef sanitizedBezier;
    N3Vector control1;
    N3Vector control2;
    N3Vector endpoint;
    N3BezierCoreSegmentType segmentType;
    N3Vector nextEndpoint;
    N3BezierCoreSegmentType nextSegmentType;
    N3Vector lastAddedEndpoint;
    N3BezierCoreSegmentType lastAddedSegmentType = N3EndBezierCoreSegmentType;
    CFIndex i;

    bezierAccessor = N3BezierCoreRandomAccessorCreateWithBezierCore(bezierCore);
    sanitizedBezier = N3BezierCoreCreateMutable();


    for (i = 0; i < N3BezierCoreRandomAccessorSegmentCount(bezierAccessor); i++) {
        segmentType = N3BezierCoreRandomAccessorGetSegmentAtIndex(bezierAccessor, i, &control1, &control2, &endpoint);
        // we can copy this segment _unless_:
        // 1. this segment is not a lineTo with the same coornates as the last added segment
        if (segmentType == N3LineToBezierCoreSegmentType &&
            N3VectorDistance(endpoint, lastAddedEndpoint) < precision) {
            continue;
        }
        if (i + 1 < N3BezierCoreRandomAccessorSegmentCount(bezierAccessor)) {
            nextSegmentType = N3BezierCoreRandomAccessorGetSegmentAtIndex(bezierAccessor, i + 1, NULL, NULL, &nextEndpoint);
            // 2. the next segment is a close or lineTo that goes to this same point
            if ((nextSegmentType == N3CloseBezierCoreSegmentType/* || nextSegmentType == N3LineToBezierCoreSegmentType*/) &&
                N3VectorDistance(endpoint, nextEndpoint) < precision) {
                continue;
            }
        }

        N3BezierCoreAddSegment(sanitizedBezier, segmentType, control1, control2, endpoint);
        lastAddedEndpoint = endpoint;
        lastAddedSegmentType = segmentType;
    }

    N3BezierCoreRandomAccessorRelease(bezierAccessor);

    return sanitizedBezier;
}

N3MutableBezierCoreRef CMRBezierCoreCreateMutableOutlineWithNormal(N3BezierCoreRef bezierCore, CGFloat distance, CGFloat spacing, N3Vector projectionNormal)
{
    N3BezierCoreRef flattenedBezierCore;
    N3MutableBezierCoreRef outlineBezier;
    N3Vector endpoint;
    N3Vector endpointNormal;
    CGFloat length;
    NSInteger i;
    NSUInteger numVectors;
    N3VectorArray vectors;
    N3VectorArray tangents;
    N3VectorArray normals;
    N3VectorArray side;
    BOOL closed;

    assert(N3BezierCoreSubpathCount(bezierCore) == 1); // this only works when there is a single subpath

    if (N3BezierCoreSegmentCount(bezierCore) < 2) {
        return NULL;
    }

    if (N3BezierCoreGetSegmentAtIndex(bezierCore, N3BezierCoreSegmentCount(bezierCore) - 1, NULL, NULL, NULL) == N3CloseBezierCoreSegmentType) {
        closed = YES;
    } else {
        closed = NO;
    }

    if (N3BezierCoreHasCurve(bezierCore)) {
        flattenedBezierCore = N3BezierCoreCreateMutableCopy(bezierCore);
        N3BezierCoreSubdivide((N3MutableBezierCoreRef)flattenedBezierCore, N3BezierDefaultSubdivideSegmentLength);
        N3BezierCoreFlatten((N3MutableBezierCoreRef)flattenedBezierCore, N3BezierDefaultFlatness);

        N3BezierCoreRef tempBezier = flattenedBezierCore;
        flattenedBezierCore = N3BezierCoreCreateCopyBySanitizing(flattenedBezierCore, spacing/2.0);
        N3BezierCoreRelease(tempBezier);
    } else {
        flattenedBezierCore = N3BezierCoreRetain(bezierCore);
    }

    length = N3BezierCoreLength(flattenedBezierCore);

    if (spacing * 2 >= length) {
        N3BezierCoreRelease(flattenedBezierCore);
        return NULL;
    }

    numVectors = round(length/spacing);

    vectors = malloc(numVectors * sizeof(N3Vector));
    tangents = malloc(numVectors * sizeof(N3Vector));
    normals = malloc(numVectors * sizeof(N3Vector));
    side = malloc(numVectors * sizeof(N3Vector));
    outlineBezier = N3BezierCoreCreateMutable();

    numVectors = N3BezierCoreGetVectorInfo(flattenedBezierCore, spacing, 0, N3VectorZero, vectors, tangents, NULL, numVectors);
    endpoint = N3BezierCoreVectorAtEnd(flattenedBezierCore);
    endpointNormal = N3VectorScalarMultiply(N3VectorNormalize(N3VectorCrossProduct(projectionNormal, N3BezierCoreTangentAtEnd(flattenedBezierCore))), distance);

    memcpy(normals, tangents, numVectors * sizeof(N3Vector));
    N3VectorCrossProductVectors(projectionNormal, normals, numVectors);
    N3VectorNormalizeVectors(normals, numVectors);
    N3VectorScalarMultiplyVectors(distance, normals, numVectors);

    memcpy(side, vectors, numVectors * sizeof(N3Vector));
    N3VectorAddVectors(side, normals, numVectors);

    N3BezierCoreAddSegment(outlineBezier, N3MoveToBezierCoreSegmentType, N3VectorZero, N3VectorZero, side[0]);
    for (i = 1; i < numVectors; i++) {
        N3BezierCoreAddSegment(outlineBezier, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, side[i]);
    }
    if (closed) {
        N3BezierCoreAddSegment(outlineBezier, N3CloseBezierCoreSegmentType, N3VectorZero, N3VectorZero, N3VectorZero);
    } else {
        N3BezierCoreAddSegment(outlineBezier, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, N3VectorAdd(endpoint, endpointNormal));
    }

    N3VectorScalarMultiplyVectors(-1.0, normals, numVectors);

    memcpy(side, vectors, numVectors * sizeof(N3Vector));
    N3VectorAddVectors(side, normals, numVectors);

    N3BezierCoreAddSegment(outlineBezier, N3MoveToBezierCoreSegmentType, N3VectorZero, N3VectorZero, side[0]);
    for (i = 1; i < numVectors; i++) {
        N3BezierCoreAddSegment(outlineBezier, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, side[i]);
    }
    if (closed) {
        N3BezierCoreAddSegment(outlineBezier, N3CloseBezierCoreSegmentType, N3VectorZero, N3VectorZero, N3VectorZero);
    } else {
        N3BezierCoreAddSegment(outlineBezier, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, N3VectorAdd(endpoint, N3VectorInvert(endpointNormal)));
    }

    free(vectors);
    free(normals);
    free(tangents);
    free(side);

    N3BezierCoreRelease(flattenedBezierCore);

    return outlineBezier;
}


N3MutableBezierCoreRef CMRBezierCoreCreateMutableOutline(N3BezierCoreRef bezierCore, CGFloat distance, CGFloat spacing, N3Vector initialNormal)
{
    N3BezierCoreRef flattenedBezierCore;
    N3MutableBezierCoreRef outlineBezier;
    N3Vector endpoint;
    N3Vector endpointNormal;
    CGFloat length;
    NSInteger i;
    NSUInteger numVectors;
    N3VectorArray vectors;
    N3VectorArray normals;
    N3VectorArray scaledNormals;
    N3VectorArray side;
    BOOL closed;

    assert(N3BezierCoreSubpathCount(bezierCore) == 1); // this only works when there is a single subpath

    if (N3BezierCoreSegmentCount(bezierCore) < 2) {
        return NULL;
    }

    if (N3BezierCoreGetSegmentAtIndex(bezierCore, N3BezierCoreSegmentCount(bezierCore) - 1, NULL, NULL, NULL) == N3CloseBezierCoreSegmentType) {
        closed = YES;
    } else {
        closed = NO;
    }

    if (N3BezierCoreHasCurve(bezierCore)) {
        flattenedBezierCore = N3BezierCoreCreateMutableCopy(bezierCore);
        N3BezierCoreSubdivide((N3MutableBezierCoreRef)flattenedBezierCore, N3BezierDefaultSubdivideSegmentLength);
        N3BezierCoreFlatten((N3MutableBezierCoreRef)flattenedBezierCore, N3BezierDefaultFlatness);

        N3BezierCoreRef tempBezier = flattenedBezierCore;
        flattenedBezierCore = N3BezierCoreCreateCopyBySanitizing(flattenedBezierCore, spacing/2.0);
        N3BezierCoreRelease(tempBezier);
    } else {
        flattenedBezierCore = N3BezierCoreRetain(bezierCore);
    }

    length = N3BezierCoreLength(flattenedBezierCore);

    if (spacing * 2 >= length) {
        N3BezierCoreRelease(flattenedBezierCore);
        return NULL;
    }

    numVectors = length/spacing + 1.0;

    vectors = malloc(numVectors * sizeof(N3Vector));
    normals = malloc(numVectors * sizeof(N3Vector));
    scaledNormals = malloc(numVectors * sizeof(N3Vector));
    side = malloc(numVectors * sizeof(N3Vector));
    outlineBezier = N3BezierCoreCreateMutable();

    numVectors = CMRBezierCoreGetVectorInfo(flattenedBezierCore, spacing, 0, initialNormal, vectors, NULL, normals, numVectors);
    N3BezierCoreGetSegmentAtIndex(flattenedBezierCore, N3BezierCoreSegmentCount(flattenedBezierCore) - 1, NULL, NULL, &endpoint);
    endpointNormal = N3VectorNormalize(N3VectorSubtract(normals[numVectors-1], N3VectorProject(normals[numVectors-1], N3BezierCoreTangentAtEnd(flattenedBezierCore))));
    endpointNormal = N3VectorScalarMultiply(endpointNormal, distance);

    memcpy(scaledNormals, normals, numVectors * sizeof(N3Vector));
    N3VectorScalarMultiplyVectors(distance, scaledNormals, numVectors);

    memcpy(side, vectors, numVectors * sizeof(N3Vector));
    N3VectorAddVectors(side, scaledNormals, numVectors);

    N3BezierCoreAddSegment(outlineBezier, N3MoveToBezierCoreSegmentType, N3VectorZero, N3VectorZero, side[0]);
    for (i = 1; i < numVectors; i++) {
        N3BezierCoreAddSegment(outlineBezier, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, side[i]);
    }
    if (closed) {
        N3BezierCoreAddSegment(outlineBezier, N3CloseBezierCoreSegmentType, N3VectorZero, N3VectorZero, N3VectorZero);
    } else {
        N3BezierCoreAddSegment(outlineBezier, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, N3VectorAdd(endpoint, endpointNormal));
    }

    memcpy(scaledNormals, normals, numVectors * sizeof(N3Vector));
    N3VectorScalarMultiplyVectors(-distance, scaledNormals, numVectors);

    memcpy(side, vectors, numVectors * sizeof(N3Vector));
    N3VectorAddVectors(side, scaledNormals, numVectors);

    N3BezierCoreAddSegment(outlineBezier, N3MoveToBezierCoreSegmentType, N3VectorZero, N3VectorZero, side[0]);
    for (i = 1; i < numVectors; i++) {
        N3BezierCoreAddSegment(outlineBezier, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, side[i]);
    }
    if (closed) {
        N3BezierCoreAddSegment(outlineBezier, N3CloseBezierCoreSegmentType, N3VectorZero, N3VectorZero, N3VectorZero);
    } else {
        N3BezierCoreAddSegment(outlineBezier, N3LineToBezierCoreSegmentType, N3VectorZero, N3VectorZero, N3VectorAdd(endpoint, N3VectorInvert(endpointNormal)));
    }

    free(vectors);
    free(normals);
    free(scaledNormals);
    free(side);

    N3BezierCoreRelease(flattenedBezierCore);

    return outlineBezier;
}

CFIndex CMRBezierCoreGetVectorInfo(N3BezierCoreRef bezierCore, CGFloat spacing, CGFloat startingDistance, N3Vector initialNormal,
                                  N3VectorArray vectors, N3VectorArray tangents, N3VectorArray normals, CFIndex numVectors)
{
    N3BezierCoreRef flattenedBezierCore;
    N3BezierCoreIteratorRef bezierCoreIterator;
    N3Vector nextVector;
    N3Vector startVector;
    N3Vector endVector;
    N3Vector previousTangentVector;
    N3Vector nextTangentVector;
    N3Vector tangentVector;
    N3Vector startTangentVector;
    N3Vector endTangentVector;
    N3Vector previousNormalVector;
    N3Vector nextNormalVector;
    N3Vector normalVector;
    N3Vector startNormalVector;
    N3Vector endNormalVector;
    N3Vector segmentDirection;
    N3Vector nextSegmentDirection;
    N3Vector closeVector;
    N3Vector firstNormalVector;
    N3Vector firstTangentVector;
    CGFloat segmentLength;
    CGFloat distanceTraveled;
    CGFloat extraDistance;
    CFIndex i;
    bool done;

    if (numVectors == 0 || N3BezierCoreSegmentCount(bezierCore) < 2) {
        return 0;
    }

    assert(normals == NULL || N3BezierCoreSubpathCount(bezierCore) == 1); // this only works when there is a single subpath
    assert(N3BezierCoreSubpathCount(bezierCore) == 1); // TODO! I should fix this to be able to handle moveTo as long as normals don't matter

    if (N3BezierCoreHasCurve(bezierCore)) {
        flattenedBezierCore = N3BezierCoreCreateMutableCopy(bezierCore);
        N3BezierCoreSubdivide((N3MutableBezierCoreRef)flattenedBezierCore, N3BezierDefaultSubdivideSegmentLength);
        N3BezierCoreFlatten((N3MutableBezierCoreRef)flattenedBezierCore, N3BezierDefaultFlatness);
    } else {
        flattenedBezierCore = N3BezierCoreRetain(bezierCore);
    }

    bezierCoreIterator = N3BezierCoreIteratorCreateWithBezierCore(flattenedBezierCore);

    extraDistance = startingDistance; // distance that was traveled past the last point
    done = false;
    i = 0;
    startVector = N3VectorZero;
    endVector = N3VectorZero;

    N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &startVector);
    N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &endVector);
    segmentDirection = N3VectorNormalize(N3VectorSubtract(endVector, startVector));
    segmentLength = N3VectorDistance(endVector, startVector);

    normalVector = N3VectorNormalize(N3VectorSubtract(initialNormal, N3VectorProject(initialNormal, segmentDirection)));
    if(N3VectorEqualToVector(normalVector, N3VectorZero)) {
        normalVector = N3VectorNormalize(N3VectorCrossProduct(N3VectorMake(-1.0, 0.0, 0.0), segmentDirection));
        if(N3VectorEqualToVector(normalVector, N3VectorZero)) {
            normalVector = N3VectorNormalize(N3VectorCrossProduct(N3VectorMake(0.0, 1.0, 0.0), segmentDirection));
        }
    }

    tangentVector = segmentDirection;

    firstNormalVector = normalVector;
    firstTangentVector = tangentVector;

    // if the last segment is a close, find the last segment to calculate the previous normal and tangent
    if (N3BezierCoreGetSegmentAtIndex(flattenedBezierCore, N3BezierCoreSegmentCount(flattenedBezierCore) - 1, NULL, NULL, NULL) == N3CloseBezierCoreSegmentType) {
        N3BezierCoreGetSegmentAtIndex(flattenedBezierCore, N3BezierCoreSegmentCount(flattenedBezierCore) - 2, NULL, NULL, &closeVector);
        previousTangentVector = N3VectorNormalize(N3VectorSubtract(startVector, closeVector));

        previousNormalVector = N3VectorBend(normalVector, tangentVector, previousTangentVector);
        previousNormalVector = N3VectorSubtract(previousNormalVector, N3VectorProject(previousNormalVector, previousTangentVector)); // make sure the new vector is really normal
        previousNormalVector = N3VectorNormalize(previousNormalVector);
    } else {
        previousTangentVector = segmentDirection;
        previousNormalVector = normalVector;
    }

    while (done == false) {
        distanceTraveled = extraDistance;

        if (N3BezierCoreIteratorIsAtEnd(bezierCoreIterator)) {
            // if the last segment is a close, find the last segment to calculate the previous normal and tangent
            if (N3BezierCoreGetSegmentAtIndex(flattenedBezierCore, N3BezierCoreSegmentCount(flattenedBezierCore) - 1, NULL, NULL, NULL) == N3CloseBezierCoreSegmentType) {
                nextNormalVector = firstNormalVector;
                nextTangentVector = firstTangentVector;
            } else {
                nextNormalVector = normalVector;
                nextTangentVector = tangentVector;
            }

            nextVector = endVector;
            done = true;
        } else {
            N3BezierCoreIteratorGetNextSegment(bezierCoreIterator, NULL, NULL, &nextVector);
            nextSegmentDirection = N3VectorNormalize(N3VectorSubtract(nextVector, endVector));
            nextNormalVector = N3VectorBend(normalVector, segmentDirection, nextSegmentDirection);
            nextNormalVector = N3VectorSubtract(nextNormalVector, N3VectorProject(nextNormalVector, nextSegmentDirection)); // make sure the new vector is really normal
            nextNormalVector = N3VectorNormalize(nextNormalVector);

            nextTangentVector = nextSegmentDirection;
        }
        startNormalVector = N3VectorNormalize(N3VectorLerp(previousNormalVector, normalVector, 0.5));
        endNormalVector = N3VectorNormalize(N3VectorLerp(nextNormalVector, normalVector, 0.5));

        startTangentVector = N3VectorNormalize(N3VectorLerp(previousTangentVector, tangentVector, 0.5));
        endTangentVector = N3VectorNormalize(N3VectorLerp(nextTangentVector, tangentVector, 0.5));

        while(distanceTraveled < segmentLength)
        {
            if (vectors) {
                vectors[i] = N3VectorAdd(startVector, N3VectorScalarMultiply(segmentDirection, distanceTraveled));
            }
            if (tangents) {
                tangents[i] = N3VectorNormalize(N3VectorLerp(startTangentVector, endTangentVector, distanceTraveled/segmentLength));

            }
            if (normals) {
                normals[i] = N3VectorNormalize(N3VectorLerp(startNormalVector, endNormalVector, distanceTraveled/segmentLength));
            }
            i++;
            if (i >= numVectors) {
                N3BezierCoreIteratorRelease(bezierCoreIterator);
                N3BezierCoreRelease(flattenedBezierCore);
                flattenedBezierCore = NULL;
                return i;
            }

            distanceTraveled += spacing;
        }

        extraDistance = distanceTraveled - segmentLength;

        previousNormalVector = normalVector;
        normalVector = nextNormalVector;
        previousTangentVector = tangentVector;
        tangentVector = nextTangentVector;
        segmentDirection = nextSegmentDirection;
        startVector = endVector;
        endVector = nextVector;
        segmentLength = N3VectorDistance(startVector, endVector);

    }

    N3BezierCoreIteratorRelease(bezierCoreIterator);
    N3BezierCoreRelease(flattenedBezierCore);
    flattenedBezierCore = NULL;
    
    return i;
}









