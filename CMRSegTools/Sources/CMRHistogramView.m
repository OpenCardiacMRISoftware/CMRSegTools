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
//  CMRHistogramView.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 10/11/12.
//  Copyright (c) 2012 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRHistogramView.h"

#import <OsiriX/OSIROIFloatPixelData.h>

static const CGFloat RIM_PADDING = 10.0;

const NSInteger CMRHistogramComputeWidth = INT_MAX;

@interface CMRHistogramView ()

- (void)buildHistograms;
- (double)bessel0:(double)x;

@end

@implementation CMRHistogramView

@synthesize delegate = _delegate;
@synthesize autocalcBinFormula = _autocalcBinFormula;
@synthesize binWidth = _binWidth;
@synthesize domainMin = _domainMin;
@synthesize domainMax = _domainMax;
@synthesize binCount = _binCount;
@synthesize rangeMax = _rangeMax;
@synthesize rangeMin = _rangeMin;
@synthesize showCursor = _showCursor;

//@synthesize cursorValueMin = _cursorValueMin, cursorValueMax = _cursorValueMax;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _ROIFloatPixelDataArray = [[NSMutableArray alloc] init];
        _displayColorArray = [[NSMutableArray alloc] init];
        _binWidth = 1;
        displayGaussian = NO;
        displayRice = NO;
        _cursorValueMin = -MAXFLOAT;
        _cursorValueMax = MAXFLOAT;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _ROIFloatPixelDataArray = [[NSMutableArray alloc] init];
        _displayColorArray = [[NSMutableArray alloc] init];
        _binWidth = 1;
        displayGaussian = NO;
        displayRice = NO;
        _cursorValueMin = -MAXFLOAT;
        _cursorValueMax = MAXFLOAT;
    }
    
    return self;
}

- (void)dealloc
{
    [_ROIFloatPixelDataArray release];
    _ROIFloatPixelDataArray = nil;
    [_displayColorArray release];
    _displayColorArray = nil;
    [_histograms release];
    _histograms = nil;
    _delegate = nil;

    [super dealloc];
}

- (void)setCursorValueMin:(float)minValue max:(float)maxValue
{
    if (self.cursorValueMin == minValue && self.cursorValueMax == maxValue)
        return;
    
    self.cursorValueMin = minValue;
    self.cursorValueMax = maxValue;
    
    [self setNeedsDisplay:YES];
}

- (void)setShowCursor:(BOOL)showCursor
{
    if (showCursor != _showCursor) {
        _showCursor = showCursor;
        [self setNeedsDisplay:YES];
    }
}

//- (void)setCursorBinToValue:(float)binValue
//{
//    if (_binWidth) {
//        [self setCursorBin:(binValue - _domainMin) / _binWidth];
//    }
//}

- (NSArray *)ROIFloatPixelData
{
    return [_ROIFloatPixelDataArray copy];
}

- (NSArray *)displayColors
{
    return [_displayColorArray copy];
}

- (void)removeAllROIFloatPixelData
{
    [_ROIFloatPixelDataArray removeAllObjects];
    [_displayColorArray removeAllObjects];
    [_histograms release];
    
    _histograms = nil;
    [self setNeedsDisplay:YES];
}

- (void)addROIFloatPixelData:(OSIROIFloatPixelData *)ROIFloatPixelData displayColor:(NSColor *)displayColor
{
    [_ROIFloatPixelDataArray addObject:ROIFloatPixelData];
    [_displayColorArray addObject:displayColor];
    [_histograms release];
    _histograms = nil;
    [self setNeedsDisplay:YES];
}

- (void)addGaussianWithMean:(NSPoint)mean withStd:(NSPoint)devStandard withW:(NSPoint)w numberOfPix:(double)numberOfPix typeOfDistribution:(NSString*)typeOfDistribution displayColor:(NSColor *)displayColor
{
    _mean = mean;
    _std = devStandard;
    _w = w;
    _numberOfPixel = numberOfPix;
    _displayColorGaussian = displayColor;
    if ([typeOfDistribution isEqual: @"Gaussian"]) {
        displayGaussian = YES;
    }
    else if ([typeOfDistribution isEqual: @"Rice"]){
        displayRice = YES;
    }
    [self setNeedsDisplay:YES];
}

- (NSInteger)pixelDataMin:(float*)min max:(float*)max {
    NSInteger totalFloatCount = 0;
    
    for (OSIROIFloatPixelData *pixelData in _ROIFloatPixelDataArray) {
        totalFloatCount += [pixelData floatCount];
        if ([pixelData floatCount]) {
            *min = MIN(*min, [pixelData intensityMin]);
            *max = MAX(*max, [pixelData intensityMax]);
        }
    }
    
    return totalFloatCount;
}

- (void)autocalcRanges
{
    
    if ([_ROIFloatPixelDataArray count] == 0) {
        _domainMin = 0;
        _domainMax = 0;
        _rangeMin = 0;
        _rangeMax = 0;
        _binCount = 0;
        return;
    }
    
    if (_autocalcBinFormula == CMRHistogramViewNoBinFormula && _binWidth <= 0.0) {
        _domainMin = 0;
        _domainMax = 0;
        _rangeMin = 0;
        _rangeMax = 0;
        _binCount = 0;
        return;
    }
    
    _domainMin = CGFLOAT_MAX;
    _domainMax = CGFLOAT_MIN;
    _rangeMin = 0;
    _rangeMax = 0;

    NSInteger totalFloatCount = [self pixelDataMin:&_domainMin max:&_domainMax];
    
    if (totalFloatCount == 0) {
        _domainMin = 0;
        _domainMax = 0;
        _rangeMin = 0;
        _rangeMax = 0;
        _binCount = 0;
        return;
    }

    // set the bin width
    if (_autocalcBinFormula != CMRHistogramViewNoBinFormula) {
        switch (_autocalcBinFormula) {
            case CMRHistogramViewSquareRootBinFormula:
                _binCount = (float)ceil(sqrt((double)totalFloatCount));
                break;
            case CMRHistogramViewOneBinFormula:
                _binCount = 1.0;
                break;
            case CMRHistogramViewSturgesBinFormula:
                _binCount = ceil(log2((double)totalFloatCount) + 1.0);
                break;
            case CMRHistogramViewRiceBinFormula:
                _binCount = ceil(pow((double)totalFloatCount, 1.0/3.0) * 2.0);
                break;
            case CMRHistogramViewNoBinFormula:
                assert(0); // this can't happen
        }
        _binWidth = MAX(ceilf((_domainMax - _domainMin) / (float)_binCount), 1.0);
    }
    
    if (_binWidth == CMRHistogramComputeWidth)
        _binWidth = (_domainMax - _domainMin) / _binCount;
    else _binCount = MAX((NSUInteger)ceilf((_domainMax - _domainMin) / _binWidth), 1);

    _domainMax = ((float)_binCount * _binWidth) + _domainMin;
    
    [_histograms release];
    _histograms = nil;
    [self buildHistograms];
    
    NSUInteger i;
    for (i = 0; i < _binCount; i++) {
        NSUInteger histogramHeight = 0;
        
        for (NSData *histogramData in _histograms) {
            if (i < [histogramData length]) { // be defensive
                histogramHeight += ((NSUInteger *)[histogramData bytes])[i];
            }
        }
        
        _rangeMax = MAX(_rangeMax, histogramHeight);
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (_binCount == 0) {
        return;
    }
    
    [self buildHistograms];
    
    CGFloat barWidth = (NSWidth([self bounds]) - (RIM_PADDING*2)) / (CGFloat)_binCount;
    CGFloat incrementHeight = (NSHeight([self bounds]) - RIM_PADDING) / (CGFloat)_rangeMax;
    NSUInteger *histogramBaseline = malloc(_binCount * sizeof(NSUInteger));
    memset(histogramBaseline, 0, _binCount * sizeof(NSUInteger));
    
    NSUInteger i, j;
    for (i = 0; i < [_histograms count]; i++) {
        NSColor *displayColor = [[_displayColorArray objectAtIndex:i] colorWithAlphaComponent:1.0];
        const NSUInteger *histogram = (const NSUInteger*)[[_histograms objectAtIndex:i] bytes];
        [displayColor set];
        for (j = 0; j < _binCount; j++) {
            NSRect barBox = NSMakeRect((barWidth * (CGFloat)j) + RIM_PADDING, (incrementHeight * (CGFloat)histogramBaseline[j]) + RIM_PADDING, barWidth, incrementHeight * (CGFloat)histogram[j]);
            NSRectFill(barBox);
            histogramBaseline[j] += histogram[j];
        }
    }
    
    free(histogramBaseline);
    
    if (displayGaussian) {
        double y;
        y = _w.x*(1/sqrt(2*M_PI*_std.x*_std.x)) * exp(-(0-_mean.x)*(0-_mean.x)/(2*_std.x*_std.x));
        NSPoint p1 = NSMakePoint((barWidth * (CGFloat)0) + RIM_PADDING, _numberOfPixel*incrementHeight*y+RIM_PADDING );
        NSPoint p2 = NSMakePoint((barWidth * (CGFloat)0) + RIM_PADDING, _numberOfPixel*incrementHeight*y+RIM_PADDING );
        
        for (j=1; j<_binCount; j++) {
            p1 = p2;
            y = _w.x*(1/sqrt(2*M_PI*_std.x*_std.x)) * exp(-((double)j-_mean.x)*((double)j-_mean.x)/(2*_std.x*_std.x));
            p2 = NSMakePoint((barWidth * (CGFloat)j) + RIM_PADDING, _numberOfPixel*incrementHeight*y+RIM_PADDING);
            [_displayColorGaussian set];
            [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
            
        }
        y = _w.y*(1/sqrt(2*M_PI*_std.y*_std.y)) * exp(-(0-_mean.y)*(0-_mean.y)/(2*_std.y*_std.y));
        p1 = NSMakePoint((barWidth * (CGFloat)0) + RIM_PADDING, _numberOfPixel*incrementHeight*y+RIM_PADDING );
        p2 = NSMakePoint((barWidth * (CGFloat)0) + RIM_PADDING, _numberOfPixel*incrementHeight*y+RIM_PADDING );
        
        for (j=1; j<_binCount; j++) {
            p1 = p2;
            y = _w.y*(1/sqrt(2*M_PI*_std.y*_std.y)) * exp(-((double)j-_mean.y)*((double)j-_mean.y)/(2*_std.y*_std.y));
            p2 = NSMakePoint((barWidth * (CGFloat)j) + RIM_PADDING, _numberOfPixel*incrementHeight*y+RIM_PADDING);
            [_displayColorGaussian set];
            [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
            
        }
        displayGaussian = NO;
    }
    else if (displayRice){
        double y;
        NSPoint p1 = NSMakePoint((barWidth * (CGFloat)0) + RIM_PADDING, (incrementHeight ) );
        NSPoint p2 = NSMakePoint((barWidth * (CGFloat)0) + RIM_PADDING, (incrementHeight ) );
        
        for (j=1; j<_binCount; j++) {
            p1 = p2;
            y = _w.x*((double)j/(_std.x*_std.x)) * exp(-(j*j+_mean.x*_mean.x)/(2*_std.x*_std.x))*[self bessel0:((double)j*_mean.x)/(_std.x*_std.x)];
            p2 = NSMakePoint((barWidth * (CGFloat)j) + RIM_PADDING, _numberOfPixel*incrementHeight*y+RIM_PADDING);
            [_displayColorGaussian set];
            [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
            
        }
        y = _w.y*(1/sqrt(2*M_PI*_std.y*_std.y)) * exp(-(0-_mean.y)*(0-_mean.y)/(2*_std.y*_std.y));
        p1 = NSMakePoint((barWidth * (CGFloat)0) + RIM_PADDING, _numberOfPixel*incrementHeight*y+RIM_PADDING );
        p2 = NSMakePoint((barWidth * (CGFloat)0) + RIM_PADDING, _numberOfPixel*incrementHeight*y+RIM_PADDING );
        
        for (j=1; j<_binCount; j++) {
            p1 = p2;
            y = _w.y*(1/sqrt(2*M_PI*_std.y*_std.y)) * exp(-((double)j-_mean.y)*((double)j-_mean.y)/(2*_std.y*_std.y));
            p2 = NSMakePoint((barWidth * (CGFloat)j) + RIM_PADDING, _numberOfPixel*incrementHeight*y+RIM_PADDING);
            [_displayColorGaussian set];
            [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
            
        }
        displayRice = NO;
    }
    
    
    if (_showCursor) { // draw the cursor
        CGFloat width = NSWidth(self.bounds)-(RIM_PADDING*2);
        CGFloat minLocation = ((self.cursorValueMin != -MAXFLOAT)? (self.cursorValueMin-self.domainMin)/(self.domainMax-self.domainMin)*width : 0) + RIM_PADDING;
        CGFloat maxLocation = ((self.cursorValueMax != MAXFLOAT)? (self.cursorValueMax-self.domainMin)/(self.domainMax-self.domainMin)*width : width) + RIM_PADDING;
        
        NSColor *cursorColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRCursorColor"]];
        [cursorColor set];
        
        for (NSNumber *location in @[ @(minLocation), @(maxLocation) ]) {
            CGFloat cursorCenter = location.doubleValue;
            NSBezierPath *cursorPath = [NSBezierPath bezierPath];
            [cursorPath moveToPoint:NSMakePoint(cursorCenter - 6, 0)];
            [cursorPath lineToPoint:NSMakePoint(cursorCenter, 10)];
            [cursorPath lineToPoint:NSMakePoint(cursorCenter + 6, 0)];
            [cursorPath closePath];
            [cursorPath fill];
        }
    }
}

- (double)bessel0:(double)x
{
    double ax,ans;
    double y;
    //Accumulate polynomials in double precision.
    if ((ax=fabs(x)) < 3.75) {//Polynomial fit.
        y=x/3.75;
        y*=y;
        ans=1.0+y*(3.5156229+y*(3.0899424+y*(1.2067492
                                             +y*(0.2659732+y*(0.360768e-1+y*0.45813e-2)))));
    } else {
        y=3.75/ax;
        ans=(exp(ax)/sqrt(ax))*(0.39894228+y*(0.1328592e-1
                                              +y*(0.225319e-2+y*(-0.157565e-2+y*(0.916281e-2
                                                                                 +y*(-0.2057706e-1+y*(0.2635537e-1+y*(-0.1647633e-1
                                                                                                                      +y*0.392377e-2))))))));
    }
    return ans;
}

- (void)buildHistograms
{
    if (_histograms != nil) {
        return;
    }
    const float *floatBuffer = nil;
    NSUInteger i = 0;
    NSUInteger histogramIndex = 0;
    
    _histograms = [[NSMutableArray alloc] initWithCapacity:[_ROIFloatPixelDataArray count]];
    
    for (OSIROIFloatPixelData *pixelData in _ROIFloatPixelDataArray) {
        floatBuffer = (float *)[[pixelData floatData] bytes];
        NSUInteger *histogramBuffer = malloc(_binCount * sizeof(NSUInteger));
        memset(histogramBuffer, 0, _binCount * sizeof(NSUInteger));
        
        for (i = 0; i < [pixelData floatCount]; i++) {
            histogramIndex = (floatBuffer[i] - _domainMin) / _binWidth;
            if (histogramIndex < _binCount) {
                histogramBuffer[histogramIndex]++;
            }
        }
        
        NSData *histrogramData = [[NSData alloc] initWithBytesNoCopy:histogramBuffer length:_binCount * sizeof(NSUInteger) freeWhenDone:YES];
        [_histograms addObject:histrogramData];
        [histrogramData release];
    }
}

-(void)mouseDown:(NSEvent *)event
{
    if (_binCount == 0 || _showCursor == NO)
        return;
    
    [self buildHistograms];
    
    CGFloat width = NSWidth(self.bounds)-(RIM_PADDING*2);
    CGFloat locationX = [self convertPoint:event.locationInWindow
                                  fromView:nil].x;
    
    CGFloat minLocation = ((self.cursorValueMin != -MAXFLOAT)? (self.cursorValueMin-self.domainMin)/(self.domainMax-self.domainMin)*width : 0) + RIM_PADDING;
    CGFloat maxLocation = ((self.cursorValueMax != MAXFLOAT)? (self.cursorValueMax-self.domainMin)/(self.domainMax-self.domainMin)*width : width) + RIM_PADDING;
    
    // is the click closer to the min or the max cursor?
    if (fabs(minLocation-locationX) < fabs(maxLocation-locationX)) {
        _cursorDragging = CMRHistogramViewDraggingMinCursor;
        _mouseDownCursorDeltaX = minLocation-locationX;
    } else {
        _cursorDragging = CMRHistogramViewDraggingMaxCursor;
        _mouseDownCursorDeltaX = maxLocation-locationX;
    }
    
    if (fabs(_mouseDownCursorDeltaX) > 6)
        _mouseDownCursorDeltaX = 0;
    
    [self mouseDragged:event];
}

-(void)mouseDragged:(NSEvent *)event
{
    if (_cursorDragging == CMRHistogramViewNotDraggingCursor)
        return;
    
    if (_binCount == 0)
        return;
    
    [self buildHistograms];
    
    CGFloat width = NSWidth(self.bounds)-(RIM_PADDING*2);
    CGFloat locationX = [self convertPoint:event.locationInWindow
                                  fromView:nil].x+_mouseDownCursorDeltaX;

    CGFloat value = (locationX-RIM_PADDING)/width*(self.domainMax-self.domainMin) + self.domainMin;
    if (value < _domainMin)
        value = _domainMin;
    else if (value > _domainMax)
        value = _domainMax;
    
    if (_cursorDragging == CMRHistogramViewDraggingMinCursor) {
        _cursorValueMin = value;
        if (value > _cursorValueMax)
            _cursorValueMax = value;
    } else {
        _cursorValueMax = value;
        if (value < _cursorValueMin)
            _cursorValueMin = value;
    }
    
//    // find the closest bin
//    _cursorBin = MAX(MIN(floor(((clickLocation.x + (barWidth/2.0)) - RIM_PADDING)/barWidth), _binCount), 0);
    
    if ([_delegate respondsToSelector:@selector(histogramViewDidChangeCursorValues:)])
        [_delegate histogramViewDidChangeCursorValues:self];
    
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event
{
    _cursorDragging = CMRHistogramViewNotDraggingCursor;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

- (BOOL)mouseDownCanMoveWindow
{
    return NO;
}

@end


@implementation CMRHistogramBinsButton

- (void)mouseDown:(NSEvent *)theEvent {
    [super mouseDown:theEvent];
    [NSMenu popUpContextMenu:[self.superview menu] withEvent:theEvent forView:self withFont:[NSFont menuFontOfSize:[NSFont systemFontSize]]];
}

@end


















