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
//  CMRHistogramView.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 10/11/12.
//  Copyright (c) 2012 Spaltenstein Natural Image. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CMRImageButton.h"

@class OSIROIFloatPixelData;
@protocol CMRHistogramViewDelegate;

// a histogram view knows how to display an array of OSIROIFloatPixelDatas

typedef NS_ENUM(NSInteger, CMRHistogramViewBinFormula) {
    CMRHistogramViewNoBinFormula = -1, // don't touch the bin width
    CMRHistogramViewSquareRootBinFormula,
    CMRHistogramViewOneBinFormula, // set the Bin size to 1;
    CMRHistogramViewSturgesBinFormula,
    CMRHistogramViewRiceBinFormula
};

typedef NS_ENUM(NSInteger, CMRHistogramViewCursorDragging) {
    CMRHistogramViewNotDraggingCursor,
    CMRHistogramViewDraggingMinCursor,
    CMRHistogramViewDraggingMaxCursor
};

extern const NSInteger CMRHistogramComputeWidth;

@interface CMRHistogramView : NSView
{
    id<CMRHistogramViewDelegate> _delegate;
    
    NSMutableArray *_ROIFloatPixelDataArray;
    NSMutableArray *_displayColorArray;
    NSMutableArray *_histograms;
    
    NSPoint _mean;
    NSPoint _std;
    NSPoint _w;
    NSColor* _displayColorGaussian;
    double _numberOfPixel;
    BOOL displayGaussian;
    BOOL displayRice;

    CMRHistogramViewBinFormula _autocalcBinFormula;
    
    BOOL _showCursor;
//    float _cursorValueMin, _cursorValueMax;
    CMRHistogramViewCursorDragging _cursorDragging;
    CGFloat _mouseDownCursorDeltaX;
    
    float _binWidth;
    float _domainMin;
    float _domainMax;
    NSUInteger _binCount;
    NSUInteger _rangeMax;
    NSUInteger _rangeMin;
}

@property (nonatomic, readwrite, assign) IBOutlet id<CMRHistogramViewDelegate> delegate;
@property (nonatomic, readwrite, assign) CMRHistogramViewBinFormula autocalcBinFormula;
@property (nonatomic, readwrite, assign) float binWidth;
@property (nonatomic, readwrite, assign) float domainMin;
@property (nonatomic, readwrite, assign) float domainMax;
@property (nonatomic, readwrite, assign) NSUInteger binCount;
@property (nonatomic, readwrite, assign) NSUInteger rangeMax;
@property (nonatomic, readwrite, assign) NSUInteger rangeMin;

@property (nonatomic, readwrite, assign) float cursorValueMin, cursorValueMax;
- (void)setCursorValueMin:(float)minValue max:(float)maxValue;

@property (nonatomic, readwrite, assign) BOOL showCursor;

- (NSArray *)ROIFloatPixelData;
- (NSArray *)displayColors;

- (void)removeAllROIFloatPixelData;
- (void)addROIFloatPixelData:(OSIROIFloatPixelData *)ROIFloatPixelData displayColor:(NSColor *)displayColor;

- (NSInteger)pixelDataMin:(float*)min max:(float*)max;
- (void)autocalcRanges;

- (void)addGaussianWithMean:(NSPoint)mean withStd:(NSPoint)devStandard withW:(NSPoint)w numberOfPix:(double)numberOfPix typeOfDistribution:(NSString*)typeOfDistribution displayColor:(NSColor *)displayColor;
@end

// this will be to move cursors
@protocol CMRHistogramViewDelegate <NSObject>
@optional
- (void)histogramViewDidChangeCursorValues:(CMRHistogramView *)histogramView;

@end


@interface CMRHistogramBinsButton : CMRImageButton

@end
