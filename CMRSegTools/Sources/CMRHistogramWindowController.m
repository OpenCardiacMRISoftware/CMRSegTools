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
//  CMRHistogramWindowController.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 10/11/12.
//  Copyright (c) 2012 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRSegTools.h"
#import "OsiriX+CMRSegTools.h"
#import "CMRHistogramWindowController.h"
#import "CMRHistogramView.h"
#import "CMRSegToolsDrawROIStep.h"
#import "CMRSegToolsGrowRegionStep.h"
#import "CMRSegToolsQuickDrawStep.h"
#import "CMRSegToolsAngleWiperStep.h"
#import "CMRSegToolsBEASPointStep.h"
#import "CMRHistogramWindowController+BEASSegmenter.h"

#import <OsiriX/DCM/DCMObject.h>
#import <OsiriX/DCM/DCMAttributeTag.h>
#import <OsiriX/DCM/DCMAttribute.h>

#import <OsiriX/OSIEnvironment.h>
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/OSIROIManager.h>
#import <OsiriX/OSIROI.h>
#import <OsiriX/OSIROIMask.h>
#import <OsiriX/OSIMaskROI.h>
#import <OsiriX/OSIROIFloatPixelData.h>
#import <OsiriX/OSIFloatVolumeData.h>
#import <OsiriX/Notifications.h>
#import <OsiriX/PaletteController.h>
#import <OsiriX/N3BezierPath.h>
#import <OsiriX/WaitRendering.h>

#import "CMRActivityButton.h"
#import "CMRImageButton.h"

enum _StatisticsSelectorTag {
    MyocardiumSelectorTag = 0,
    NonMISelectorTag = 1,
    MISelectorTag = 2,
    NoReflowSelectorTag = 3,
    Sector1SelectorTag = 4,
    Sector2SelectorTag = 5,
    Sector3SelectorTag = 6,
    Sector4SelectorTag = 7,
    Sector5SelectorTag = 8,
    Sector6SelectorTag = 9
};
typedef NSInteger StatisticsSelectorTag;


enum _ExportValueTag {
    TotalLVMass =       1230001,
    TotalMIMass =       1230002,
    TotalNonMIMass =    1230003,
    TotalNRMass =       1230004,
    TotalMIPercent =    1230005,
    TotalNonMIPercent = 1230006,
    TotalNRPercent =    1230007,
    TotalLVVol =        1230008,
    TotalMIVol =        1230009,
    TotalNonMIVol =     1230010,
    TotalNRVol =        1230011,
    
    SliceNumberValueTag =   500001,
    SectorNumberValueTag =  500002,
    
    ESAPercentTag =  600001,
    ESAAreaTag =  600002,
    
    ESLTag =  600000,

    MyocardiumValueTagMask =    1300000,
    MIValueTagMask =            1310000,
    NonMIValueTagMask =         1320000,
    NRValueTagMask =            1330000,
    
    AreaValueTagMask =          1,
    MeanValueTagMask =          2,
    STDDevValueTagMask =        3,
    IQRValueTagMask =           4,
    MedianValueTagMask =        5,
    MaxValueTagMask =           6,
    MinValueTagMask =           7,
    
    Segment1ValueTagMask =      4110000,
    Segment2ValueTagMask =      4120000,
    Segment3ValueTagMask =      4130000,
    Segment4ValueTagMask =      4140000,
    Segment5ValueTagMask =      4150000,
    Segment6ValueTagMask =      4160000,

    MIMassValueTagMask =        1,
    NonMIMassValueTagMask =     2,
    NRMassValueTagMask =        3,
    MIPercentValueTagMask =     4,
    NonMIPercentValueTagMask =  5,
    NRPercentValueTagMask =     6,
    LVVolValueTagMask =         7,
    MIVolValueTagMask =         8,
    NonMIVolValueTagMask =      9,
    NRVolValueTagMask =         10,
    MIAreaValueTagMask =        11,
    NonMIAreaValueTagMask =     12,
    NRAreaValueTagMask =        13,
    
};
typedef NSInteger ExportValueTag;

N3Vector CMRVectorMutiplyElements(N3Vector vector1, N3Vector vector2);
N3Vector CMRVectorMutiplyElements(N3Vector vector1, N3Vector vector2) {
    return N3VectorMake(vector1.x*vector2.x, vector1.y*vector2.y, vector1.z*vector2.z);
}

CGFloat CMRVectorSumElements(N3Vector vector);
CGFloat CMRVectorSumElements(N3Vector vector) {
    return vector.x+vector.y+vector.z;
}

@interface PaletteController (modeControlAccess)
- (NSSegmentedControl *)modeControl;
@end
@implementation PaletteController (modeControlAccess)
- (NSSegmentedControl *)modeControl
{
    return modeControl;
}
@end

@interface CMRHistogramWindowBackgroundView : NSView
@end
@implementation CMRHistogramWindowBackgroundView
- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor colorWithDeviceWhite:.2 alpha:1] set];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
}
@end

@implementation CMRPixelStatisticsPane
@synthesize heightConstraint;

- (IBAction)discosureTriangle:(id)sender
{
    [self.window layoutIfNeeded];
    if ([(NSButton *)sender state] == NSOnState) {
        [self.heightConstraint.animator setConstant:301];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CMROpenPixelStatisticsPane"];
    } else {
        [self.heightConstraint.animator setConstant:20];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"CMROpenPixelStatisticsPane"];
    }
}
@end

@implementation CMRROIEditingPane
@synthesize heightConstraint;

- (IBAction)discosureTriangle:(id)sender
{
    if ([(NSButton *)sender state] == NSOnState) {
        [self.heightConstraint.animator setConstant:366];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CMROpenROIEditingPane"];
    } else {
        [self.heightConstraint.animator setConstant:25];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"CMROpenROIEditingPane"];
    }
}
@end

@interface CMRHistogramWindowController ()
@property (nonatomic, readwrite, retain) OSIVolumeWindow *volumeWindow;
- (void)_roisDidUpdateNotification:(NSNotification *)notification;
- (void)_colorsDidUpdateNotification:(NSNotification *)notification;
- (void)_volumeWindowDidCloseNotification:(NSNotification *)notification;
- (void)_volumeWindowDidChangeDataNotification:(NSNotification *)notification;

- (void)_setBrushToolToDraw;

- (void)_startStep:(CMRSegToolsStep *)step;

- (NSArray *)_sharedStringsKeys;
- (NSArray *)_sheet1Keys;

- (NSDictionary *)_sharedStringsReplacementValues;
- (NSDictionary *)_sheet1ReplacementValues;
- (NSString *)_stringValueFromDicomGroup:(int)group element:(int)element;
- (NSString *)_stringForISOLatinEncoding:(NSString *)string;
- (NSString *)_stringByEncodingXMLCharacters:(NSString *)string;
- (CGFloat)_maskVolume:(OSIROIMask *)roiMask floatVolumeData:(OSIFloatVolumeData *)floatVolumeData;
- (CGFloat)_maskArea:(OSIROIMask *)roiMask floatVolumeData:(OSIFloatVolumeData *)floatVolumeData;

- (void)_update3DLabels;

@end

@implementation CMRHistogramWindowController

@synthesize volumeWindow = _volumeWindow;
@synthesize histogramView = _histogramView;
@synthesize histogramBinsButton = _histogramBinsButton;

//@synthesize histogramBinsCountChoice = _histogramBinsCountChoice;

@synthesize pixelStatisticsPane;
@synthesize histogramPane;
@synthesize roiEditingPane;

@synthesize statisticsLabelsView;
@synthesize regionStatisticsLabelsPane;
@synthesize FWHMStatisticsLabelsPane;
@synthesize displayedStatisticsLabels;

@synthesize section1NonMI;
@synthesize section2NonMI;
@synthesize section3NonMI;
@synthesize section4NonMI;
@synthesize section5NonMI;
@synthesize section6NonMI;

@synthesize section1MI;
@synthesize section2MI;
@synthesize section3MI;
@synthesize section4MI;
@synthesize section5MI;
@synthesize section6MI;

@synthesize section1NR;
@synthesize section2NR;
@synthesize section3NR;
@synthesize section4NR;
@synthesize section5NR;
@synthesize section6NR;

@synthesize statisticsSelectorPopUp;
@synthesize sector1MenuItem;
@synthesize sector2MenuItem;
@synthesize sector3MenuItem;
@synthesize sector4MenuItem;
@synthesize sector5MenuItem;
@synthesize sector6MenuItem;

@synthesize myocardiumArea;
@synthesize myocardiumMean;
@synthesize myocardiumStddev;
@synthesize myocardiumIQR;
@synthesize myocardiumMedian;
@synthesize myocardiumMin;
@synthesize myocardiumMax;

@synthesize percentNonMI3D;
@synthesize areaNonMI3D;
@synthesize weightNonMI3D;
@synthesize volumeNonMI3D;
@synthesize percentMI3D;
@synthesize areaMI3D;
@synthesize weightMI3D;
@synthesize volumeMI3D;
@synthesize percentNR3D;
@synthesize areaNR3D;
@synthesize weightNR3D;
@synthesize volumeNR3D;

@synthesize percentNonMI2D;
@synthesize areaNonMI2D;
@synthesize weightNonMI2D;
@synthesize volumeNonMI2D;
@synthesize percentMI2D;
@synthesize areaMI2D;
@synthesize weightMI2D;
@synthesize volumeMI2D;
@synthesize percentNR2D;
@synthesize areaNR2D;
@synthesize weightNR2D;
@synthesize volumeNR2D;

@synthesize ESLLabel;
@synthesize ESLTextLabel;
@synthesize ESALabel;
@synthesize ESASurfaceLabel;
@synthesize ESATextLabel;

@synthesize visibleOnlyLabel;

@synthesize minTransmurality;
@synthesize minTransmuralityLabel;
@synthesize maxTransmurality;
@synthesize maxTransmuralityLabel;
@synthesize meanTransmurality;
@synthesize meanTransmuralityLabel;

@synthesize quickDrawButton;

@synthesize epicardiumButton;
@synthesize endocardiumButton;
@synthesize LVRVButton;
@synthesize drawSegmentsCheckbox;
@synthesize drawSegmentsLabel;

@synthesize runBEASButton;

@synthesize histogramThresholdCheckbox;
@synthesize histogramThresholdTextLabel;
//@synthesize histogramThresholdLabel;

@synthesize stddevStepper;
@synthesize stddevTextField;
@synthesize stddevLabel;
@synthesize segmentStepper;
@synthesize segmentTextField;
@synthesize segmentLabel;
@synthesize meanLabel;
@synthesize sigmaLabel;
@synthesize remoteThresholdLabel;
@synthesize meanTextLabel;
@synthesize sigmaTextLabel;
@synthesize thresholdTextLabel;

@synthesize angleWiperButton;

@synthesize popUpSegmentation;
@synthesize popUpSegmentationProgressIndicator;
@synthesize meanLabelFWHM;
@synthesize ImaxLabelFWHM;
@synthesize remoteThresholdLabelFWHM;
@synthesize meanTextLabelFWHM;
@synthesize ImaxTextLabelFWHM;
@synthesize thresholdTextLabelFWHM;
@synthesize remoteMessage;
@synthesize withNR;
@synthesize NRCheckbox;

@synthesize pixelStatisticsDisclosure;
@synthesize roiEditingDisclosure;

@synthesize growIncludeRegionButton;

@synthesize includeROIButton;

@synthesize excludeROIButton;

@synthesize noReflowROIButton;

@synthesize growNoReflowRegionButton;

@synthesize sectionNumberPopUpButton;

@synthesize importROIsButton;
@synthesize importCheckbox;

- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow
{
    if ( (self = [super initWithWindowNibName:@"CMRHistogramWindowController"])) {
        self.volumeWindow = volumeWindow;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_roisDidUpdateNotification:) name:CMRSegToolsROIsDidUpdateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_colorsDidUpdateNotification:) name:CMRSegToolsColorsDidUpdateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_volumeWindowDidCloseNotification:) name:OSIVolumeWindowDidCloseNotification object:volumeWindow];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_volumeWindowDidChangeDataNotification:) name:OSIVolumeWindowDidChangeDataNotification object:volumeWindow];
        
        [self retain]; // matched in - (void)windowWillClose:(NSNotification *)notification
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.volumeWindow = nil;
    self.histogramView = nil;
    self.pixelStatisticsPane = nil;
    self.histogramPane = nil;
    self.roiEditingPane = nil;
    self.regionStatisticsLabelsPane = nil;
    self.FWHMStatisticsLabelsPane = nil;
    
    [activeStep release];
    activeStep = nil;
    
    [super dealloc];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	[self autorelease]; // from the retain in init
}

- (void)awakeFromNib
{
    NSView *contentView = [self.window contentView];

    [contentView addSubview:self.pixelStatisticsPane];
    [contentView addSubview:self.histogramPane];
    [contentView addSubview:self.roiEditingPane];

    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.pixelStatisticsPane attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual
                                                               toItem:contentView attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.pixelStatisticsPane attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual
                                                               toItem:contentView attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.pixelStatisticsPane attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual
                                                               toItem:contentView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.pixelStatisticsPane attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                               toItem:self.histogramPane attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.histogramPane attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual
                                                               toItem:contentView attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.histogramPane attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual
                                                               toItem:contentView attribute:NSLayoutAttributeRight multiplier:1 constant:0]];

    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.histogramPane attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                               toItem:self.roiEditingPane attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.roiEditingPane attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual
                                                               toItem:contentView attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.roiEditingPane attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual
                                                               toItem:contentView attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    [contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.roiEditingPane attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                               toItem:contentView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];

    NSLayoutConstraint *pixelStatisticsPaneHeightConstraint = [NSLayoutConstraint constraintWithItem:pixelStatisticsPane attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual
                                                                                              toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:0];
    NSLayoutConstraint *roiEditingPaneHeightConstraint = [NSLayoutConstraint constraintWithItem:roiEditingPane attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual
                                                                                         toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:0];
    [pixelStatisticsPane addConstraint:pixelStatisticsPaneHeightConstraint];
    [roiEditingPane addConstraint:roiEditingPaneHeightConstraint];
    pixelStatisticsPane.heightConstraint = pixelStatisticsPaneHeightConstraint;
    roiEditingPane.heightConstraint = roiEditingPaneHeightConstraint;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMROpenPixelStatisticsPane"]) {
        pixelStatisticsPaneHeightConstraint.constant = 301;
        [pixelStatisticsDisclosure setState:NSOnState];
    } else {
        pixelStatisticsPaneHeightConstraint.constant = 20;
        [pixelStatisticsDisclosure setState:NSOffState];
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMROpenROIEditingPane"]) {
        roiEditingPaneHeightConstraint.constant = 366;
        [roiEditingDisclosure setState:NSOnState];
    } else {
        roiEditingPaneHeightConstraint.constant = 25;
        [roiEditingDisclosure setState:NSOffState];
    }
    
    self.histogramBinsButton.image = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:self.class] pathForResource:@"Bins" ofType:@"pdf"]] autorelease];

    [[self window] setLevel:NSFloatingWindowLevel];
    [(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded:YES];
    
    [self.volumeWindow.viewerController.window addChildWindow:self.window ordered:NSWindowAbove];
    
    if ([super respondsToSelector:@selector(awakeFromNib)]) {
        [super awakeFromNib];
    }
}

- (IBAction)showWindow:(id)sender
{
    [super showWindow:sender];
    
    [[self window] setTitle:[NSString stringWithFormat:@"SegTools: %@",[[[self.volumeWindow viewerController] window] title]]];
    [[CMRSegTools sharedInstance] updateCMRForVolumeWindow:self.volumeWindow];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self _roisDidUpdateNotification:nil];
}

- (void)setDisplayedStatisticsLabels:(CMRHistogramWindowSegmentationStatisticsLabels)newDisplayedStatisticsLabels
{
    if (newDisplayedStatisticsLabels != displayedStatisticsLabels) {
        displayedStatisticsLabels = newDisplayedStatisticsLabels;
        [[self.statisticsLabelsView subviews] enumerateObjectsUsingBlock:^(NSView *view, NSUInteger idx, BOOL *stop) {
            [view removeFromSuperview];
        }];

        NSView *newSubview = nil;
        switch (newDisplayedStatisticsLabels) {
            case CMRHistogramWindowSegmentationRegionStatisticsLabels:
                newSubview = regionStatisticsLabelsPane;
                break;
            case CMRHistogramWindowSegmentationFWHMStatisticsLabels:
                newSubview = FWHMStatisticsLabelsPane;
                break;

            default:
                break;
        }
        if (newSubview) {
            [statisticsLabelsView addSubview:newSubview];
            [statisticsLabelsView addConstraint:[NSLayoutConstraint constraintWithItem:newSubview attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual
                                                                                toItem:statisticsLabelsView attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
            [statisticsLabelsView addConstraint:[NSLayoutConstraint constraintWithItem:newSubview attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual
                                                                                toItem:statisticsLabelsView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
        }

    }
}

- (void)_colorsDidUpdateNotification:(NSNotification *)notification
{
    [self _roisDidUpdateNotification:nil];
}

- (void)_roisDidUpdateNotification:(NSNotification *)notification
{
    if (notification != nil && [[notification userInfo] objectForKey:@"volumeWindow"] != self.volumeWindow) { // notification == nil if we are calling this function directly
        return;
    }
    
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    BOOL CMR42EmulationMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"CMR42EmulationMode"];
    NSUInteger i = 0;
    
    OSIROI *myocardiumROI = [roiManager CMRFirstVisibleROIWithName:@"myocardium"];
    OSIROI *segmented = [roiManager CMRFirstVisibleROIWithName:@"segmented"];
    OSIROI *noReflow = [roiManager CMRFirstVisibleROIWithName:@"no-reflow"];
    OSIROI *segment1 = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 1"];
    OSIROI *segment2 = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 2"];
    OSIROI *segment3 = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 3"];
    OSIROI *segment4 = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 4"];
    OSIROI *segment5 = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 5"];
    OSIROI *segment6 = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 6"];
    
    [section1NonMI setStringValue:@""];
    [section2NonMI setStringValue:@""];
    [section3NonMI setStringValue:@""];
    [section4NonMI setStringValue:@""];
    [section5NonMI setStringValue:@""];
    [section6NonMI setStringValue:@""];
    
    [section1MI setStringValue:@""];
    [section2MI setStringValue:@""];
    [section3MI setStringValue:@""];
    [section4MI setStringValue:@""];
    [section5MI setStringValue:@""];
    [section6MI setStringValue:@""];
    
    [section1NR setStringValue:@""];
    [section2NR setStringValue:@""];
    [section3NR setStringValue:@""];
    [section4NR setStringValue:@""];
    [section5NR setStringValue:@""];
    [section6NR setStringValue:@""];
    
    
    [myocardiumMean setStringValue:@""];
    [myocardiumStddev setStringValue:@""];
    [myocardiumIQR setStringValue:@""];
    [myocardiumMedian setStringValue:@""];
    [myocardiumMin setStringValue:@""];
    [myocardiumMax setStringValue:@""];
    
//    [histogramThresholdLabel setStringValue:@""];
    [remoteThresholdLabel setStringValue:@""];
    [meanLabel setStringValue:@""];
    [sigmaLabel setStringValue:@""];
    
    [remoteThresholdLabelFWHM setStringValue:@""];
    [meanLabelFWHM setStringValue:@""];
    [ImaxLabelFWHM setStringValue:@""];

    [ESLLabel setStringValue:@""];
    [ESALabel setStringValue:@""];
    [ESASurfaceLabel setStringValue:@""];

    [minTransmurality setStringValue:@""];
    [maxTransmurality setStringValue:@""];
    [meanTransmurality setStringValue:@""];

    if (CMR42EmulationMode && myocardiumROI) {
        floatVolumeData = [myocardiumROI homeFloatVolumeData];
    }
    
    OSIROIMask *myocardiumMask = nil;
    OSIROIMask *segmentedMask = nil;
    OSIROIMask *noReflowMask = nil;
    OSIROIMask *healthyMask = nil;
    
    [self.histogramView removeAllROIFloatPixelData];
    if (myocardiumROI && segmented && [myocardiumROI homeFloatVolumeData] == floatVolumeData && [segmented homeFloatVolumeData] == floatVolumeData) {
        myocardiumMask = [myocardiumROI ROIMaskForFloatVolumeData:floatVolumeData];
        segmentedMask = [segmented ROIMaskForFloatVolumeData:floatVolumeData];
        
        OSIROIFloatPixelData *noReflowFloatPixelData = nil;
        if (noReflow && [noReflow homeFloatVolumeData] == floatVolumeData) {
            noReflowMask = [noReflow ROIMaskForFloatVolumeData:floatVolumeData];
            healthyMask = [myocardiumMask ROIMaskBySubtractingMask:[noReflowMask ROIMaskByUnioningWithMask:segmentedMask]];
            noReflowFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:noReflowMask floatVolumeData:floatVolumeData] autorelease];
        } else {
            healthyMask = [myocardiumMask ROIMaskBySubtractingMask:segmentedMask];
        }
        
        OSIROIFloatPixelData *segmentedFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:segmentedMask floatVolumeData:floatVolumeData] autorelease];
        OSIROIFloatPixelData *healthyFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:healthyMask floatVolumeData:floatVolumeData] autorelease];
                
        OSIROIFloatPixelData *histogramHealthyFloatPixelData = healthyFloatPixelData;
        OSIROI *remoteROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Remote_stddev_"];
        if (remoteROI) {
            OSIROIMask *remoteMask = [[remoteROI ROIMaskForFloatVolumeData:floatVolumeData] ROIMaskByIntersectingWithMask:myocardiumMask];
            OSIROIFloatPixelData *remoteMaskFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:remoteMask floatVolumeData:floatVolumeData] autorelease];
            
            float standardDevs = [[[remoteROI name] substringFromIndex:[@"CMRSegTools: Remote_stddev_" length]] floatValue];
            float mean = [remoteMaskFloatPixelData intensityMean];
            float sigma = [remoteMaskFloatPixelData intensityStandardDeviation];
            [self.meanLabel setStringValue:[NSString stringWithFormat:@"%.2f", mean]];
            [self.sigmaLabel setStringValue:[NSString stringWithFormat:@"%.2f", sigma]];
            [self.remoteThresholdLabel setStringValue:[NSString stringWithFormat:@"%.2f", mean + sigma*standardDevs]];
            
            remoteMask = [remoteMask ROIMaskByIntersectingWithMask:healthyMask];
            remoteMaskFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:remoteMask floatVolumeData:floatVolumeData] autorelease];
            NSColor *remoteColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]];
            [self.histogramView addROIFloatPixelData:remoteMaskFloatPixelData displayColor:remoteColor];
            histogramHealthyFloatPixelData  = [[[OSIROIFloatPixelData alloc] initWithROIMask:[healthyMask ROIMaskBySubtractingMask:remoteMask] floatVolumeData:floatVolumeData] autorelease];
        }
        
        OSIROI *remoteOutsideROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium;xSD_Segment_"];
        if (remoteOutsideROI) {
            NSArray *epiNameComponents = [[remoteOutsideROI name] componentsSeparatedByString:@";"];
            int seg = 0;
            float std = 0;
            for (NSString *component in epiNameComponents) {
                if ([component hasPrefix:@"xSD_Segment_"]) {
                    seg = [[component substringFromIndex:[@"xSD_Segment_" length]] integerValue];
                }
                if ([component hasPrefix:@"xSD_Remote_stddev_"]) {
                    std = [[component substringFromIndex:[@"xSD_Remote_stddev_" length]] floatValue];
                }
            }
            
            OSIROI *segmentROI = [roiManager CMRFirstVisibleROIWithName:[NSString stringWithFormat:@"myocardium segment %d",seg]];
            OSIROIMask *segmentMask = [segmentROI ROIMaskForFloatVolumeData:[myocardiumROI homeFloatVolumeData]];
            segmentMask = [segmentMask ROIMaskByIntersectingWithMask:myocardiumMask];
            OSIROIFloatPixelData *remotePixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:segmentMask floatVolumeData:floatVolumeData] autorelease];
            float mean = [remotePixelData intensityMean];
            float sigma = [remotePixelData intensityStandardDeviation];
            [self.meanLabel setStringValue:[NSString stringWithFormat:@"%.2f", mean]];
            [self.sigmaLabel setStringValue:[NSString stringWithFormat:@"%.2f", sigma]];
            [self.remoteThresholdLabel setStringValue:[NSString stringWithFormat:@"%.2f", mean + sigma*std]];
            
            segmentMask = [segmentMask ROIMaskByIntersectingWithMask:healthyMask];
            remotePixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:segmentMask floatVolumeData:floatVolumeData] autorelease];
            NSColor *remoteColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]];
            [self.histogramView addROIFloatPixelData:remotePixelData displayColor:remoteColor];
            histogramHealthyFloatPixelData  = [[[OSIROIFloatPixelData alloc] initWithROIMask:[healthyMask ROIMaskBySubtractingMask:segmentMask] floatVolumeData:floatVolumeData] autorelease];
        }
        
        OSIROI *regionROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: FWHMRegion"];
        if (regionROI) {
            OSIROIMask *regionMask = [[regionROI ROIMaskForFloatVolumeData:floatVolumeData] ROIMaskByIntersectingWithMask:myocardiumMask];
            OSIROIFloatPixelData *regionMaskFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:regionMask floatVolumeData:floatVolumeData] autorelease];
            
            OSIROIFloatPixelData *myocardiumMaskFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:myocardiumMask floatVolumeData:floatVolumeData] autorelease];
            
            float mean = [regionMaskFloatPixelData intensityMean];
            float Imax = [myocardiumMaskFloatPixelData intensityMax ];
            [self.meanLabelFWHM setStringValue:[NSString stringWithFormat:@"%.2f", mean]];
            [self.ImaxLabelFWHM setStringValue:[NSString stringWithFormat:@"%.2f", Imax]];
            [self.remoteThresholdLabelFWHM setStringValue:[NSString stringWithFormat:@"%.2f", (mean+Imax)/2]];
            
            regionMask = [regionMask ROIMaskByIntersectingWithMask:healthyMask];
            regionMaskFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:regionMask floatVolumeData:floatVolumeData] autorelease];
            NSColor *remoteColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]];
            [self.histogramView addROIFloatPixelData:regionMaskFloatPixelData displayColor:remoteColor];
            histogramHealthyFloatPixelData  = [[[OSIROIFloatPixelData alloc] initWithROIMask:[healthyMask ROIMaskBySubtractingMask:regionMask] floatVolumeData:floatVolumeData] autorelease];
        }
        
        OSIROI *regionOutsideROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium;FWHM_Segment_"];
        if (regionOutsideROI) {
            NSArray *epiNameComponents = [[regionOutsideROI name] componentsSeparatedByString:@";"];
            int seg = 0;
            for (NSString *component in epiNameComponents) {
                if ([component hasPrefix:@"FWHM_Segment_"]) {
                    seg = [[component substringFromIndex:[@"FWHM_Segment_" length]] integerValue];
                }
            }
            
            OSIROI *segmentROI = [roiManager CMRFirstVisibleROIWithName:[NSString stringWithFormat:@"myocardium segment %d",seg]];
            OSIROIMask *segmentMask = [segmentROI ROIMaskForFloatVolumeData:[myocardiumROI homeFloatVolumeData]];
            segmentMask = [segmentMask ROIMaskByIntersectingWithMask:myocardiumMask];
            OSIROIFloatPixelData *remotePixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:segmentMask floatVolumeData:floatVolumeData] autorelease];
            OSIROIFloatPixelData *myocardiumMaskFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:myocardiumMask floatVolumeData:floatVolumeData] autorelease];
            
            float mean = [remotePixelData intensityMean];
            float Imax = [myocardiumMaskFloatPixelData intensityMax ];
            [self.meanLabelFWHM setStringValue:[NSString stringWithFormat:@"%.2f", mean]];
            [self.ImaxLabelFWHM setStringValue:[NSString stringWithFormat:@"%.2f", Imax]];
            [self.remoteThresholdLabelFWHM setStringValue:[NSString stringWithFormat:@"%.2f", (mean+Imax)/2]];
            
            segmentMask = [segmentMask ROIMaskByIntersectingWithMask:healthyMask];
            remotePixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:segmentMask floatVolumeData:floatVolumeData] autorelease];
            NSColor *remoteColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]];
            [self.histogramView addROIFloatPixelData:remotePixelData displayColor:remoteColor];
            histogramHealthyFloatPixelData  = [[[OSIROIFloatPixelData alloc] initWithROIMask:[healthyMask ROIMaskBySubtractingMask:segmentMask] floatVolumeData:floatVolumeData] autorelease];
        }
        
        OSIROI *regionROI3D = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: FWHM3D"];
        if (regionROI3D) {
            OSIROIMask *regionMask = [[[regionROI3D ROIMaskForFloatVolumeData:floatVolumeData] ROIMaskByIntersectingWithMask:myocardiumMask] ROIMaskByIntersectingWithMask:healthyMask];
            OSIROIFloatPixelData *regionMaskFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:regionMask floatVolumeData:floatVolumeData] autorelease];
            NSColor *FWHMColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRFWHMColor"]];
            [self.histogramView addROIFloatPixelData:regionMaskFloatPixelData displayColor:FWHMColor];
            histogramHealthyFloatPixelData  = [[[OSIROIFloatPixelData alloc] initWithROIMask:[healthyMask ROIMaskBySubtractingMask:regionMask] floatVolumeData:floatVolumeData] autorelease];
        }
        
        OSIROI *epicardiumROIHsu = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium;HsuMean_"];
        if (epicardiumROIHsu) {
            ROI* osirixROI = [[epicardiumROIHsu osiriXROIs] anyObject];
            NSString *comment = [osirixROI comments];
            NSArray *paramComment = [comment componentsSeparatedByString:@";"];
            NSPoint mean, std, w;
            int num;
            for (NSString *param in paramComment) {
                if ([param hasPrefix:@"Mean1_"]){
                    mean.x = [[param substringFromIndex:[@"Mean1_" length]] floatValue];}
                if ([param hasPrefix:@"Mean2_"]){
                    mean.y = [[param substringFromIndex:[@"Mean2_" length]] floatValue];}
                if ([param hasPrefix:@"Std1_"]){
                    std.x = [[param substringFromIndex:[@"Std1_" length]] floatValue];}
                if ([param hasPrefix:@"Std2_"]){
                    std.y = [[param substringFromIndex:[@"Std2_" length]] floatValue];}
                if ([param hasPrefix:@"w1_"]){
                    w.x = [[param substringFromIndex:[@"w1_" length]] floatValue];}
                if ([param hasPrefix:@"w2_"]){
                    w.y = [[param substringFromIndex:[@"w2_" length]] floatValue];}
                if ([param hasPrefix:@"Num"]){
                    num = [[param substringFromIndex:[@"Num_" length]] floatValue];
                    NSColor *distributionColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRDistributionColor"]];
                    [self.histogramView addGaussianWithMean:mean withStd:std withW:w numberOfPix:num typeOfDistribution:@"Gaussian" displayColor:distributionColor];
                }
            }
        }
        
        OSIROI *epicardiumROIGMM = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium;GMM_"];
        if (epicardiumROIGMM) {
            ROI* osirixROI = [[epicardiumROIGMM osiriXROIs] anyObject];
            NSString *comment = [osirixROI comments];
            NSArray *paramComment = [comment componentsSeparatedByString:@";"];
            NSPoint mean, std, w;
            int num;
            for (NSString *param in paramComment) {
                if ([param hasPrefix:@"Mean1_"]){
                    mean.x = [[param substringFromIndex:[@"Mean1_" length]] floatValue];}
                if ([param hasPrefix:@"Mean2_"]){
                    mean.y = [[param substringFromIndex:[@"Mean2_" length]] floatValue];}
                if ([param hasPrefix:@"Std1_"]){
                    std.x = [[param substringFromIndex:[@"Std1_" length]] floatValue];}
                if ([param hasPrefix:@"Std2_"]){
                    std.y = [[param substringFromIndex:[@"Std2_" length]] floatValue];}
                if ([param hasPrefix:@"w1_"]){
                    w.x = [[param substringFromIndex:[@"w1_" length]] floatValue];}
                if ([param hasPrefix:@"w2_"]){
                    w.y = [[param substringFromIndex:[@"w2_" length]] floatValue];}
                if ([param hasPrefix:@"Num"]){
                    num = [[param substringFromIndex:[@"Num_" length]] floatValue];
                    NSColor *distributionColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRDistributionColor"]];
                    [self.histogramView addGaussianWithMean:mean withStd:std withW:w numberOfPix:num typeOfDistribution:@"Rice" displayColor:distributionColor];
                }
            }
        }

        
        if (noReflowFloatPixelData) {
            NSColor *noReflowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRNoReflowColor"]];
            [self.histogramView addROIFloatPixelData:noReflowFloatPixelData displayColor:noReflowColor];
        }
        
        NSColor *segementedColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRMIColor"]];
        [self.histogramView addROIFloatPixelData:segmentedFloatPixelData displayColor:segementedColor];
        NSColor *healthyColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRHealthyColor"]];
        [self.histogramView addROIFloatPixelData:histogramHealthyFloatPixelData displayColor:healthyColor];
        
//        [self.histogramView autocalcRanges];
        
        // fill out the fields
        
    } else if (myocardiumROI) {
        myocardiumMask = [myocardiumROI ROIMaskForFloatVolumeData:floatVolumeData];
        OSIROIFloatPixelData *floatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:myocardiumMask floatVolumeData:floatVolumeData] autorelease];
        NSColor *healthyColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRHealthyColor"]];
        [self.histogramView addROIFloatPixelData:floatPixelData displayColor:healthyColor];
//        [self.histogramView autocalcRanges];
        segmentedMask = [OSIROIMask ROIMask];
        noReflowMask = [OSIROIMask ROIMask];
        healthyMask = myocardiumMask;
    }
    
    // bins
    OSIROI *outsideROI = [roiManager visibleEpicardialROI];
    NSInteger bins = 0;
    for (NSString *component in [[outsideROI name] componentsSeparatedByString:@";"])
        if ([component hasPrefix:@"Bins_"])
            bins = [[component substringFromIndex:[@"Bins_" length]] integerValue];
    if (bins > 0) {
        self.histogramView.autocalcBinFormula = CMRHistogramViewNoBinFormula;
        self.histogramView.binCount = bins;
        self.histogramView.binWidth = CMRHistogramComputeWidth;
    } else {
        self.histogramView.autocalcBinFormula = CMRHistogramViewSquareRootBinFormula;
    }
    
    [self.histogramView autocalcRanges];
    //setneedsdisplay?
    
    if (myocardiumROI) { // fill in the myocardium fields
        NSMutableArray *segments = [NSMutableArray array];
        NSMutableArray *segmentMITextFields = [NSMutableArray array];
        NSMutableArray *segmentNonMITextFields = [NSMutableArray array];
        NSMutableArray *segmentNRTextFields = [NSMutableArray array];
        if (segment1) {
            [segments addObject:segment1];
            [segmentMITextFields addObject:section1MI];
            [segmentNonMITextFields addObject:section1NonMI];
            [segmentNRTextFields addObject:section1NR];
        }
        if (segment2) {
            [segments addObject:segment2];
            [segmentMITextFields addObject:section2MI];
            [segmentNonMITextFields addObject:section2NonMI];
            [segmentNRTextFields addObject:section2NR];
        }
        if (segment3) {
            [segments addObject:segment3];
            [segmentMITextFields addObject:section3MI];
            [segmentNonMITextFields addObject:section3NonMI];
            [segmentNRTextFields addObject:section3NR];
        }
        if (segment4) {
            [segments addObject:segment4];
            [segmentMITextFields addObject:section4MI];
            [segmentNonMITextFields addObject:section4NonMI];
            [segmentNRTextFields addObject:section4NR];
        }
        if (segment5) {
            [segments addObject:segment5];
            [segmentMITextFields addObject:section5MI];
            [segmentNonMITextFields addObject:section5NonMI];
            [segmentNRTextFields addObject:section5NR];
        }
        if (segment6) {
            [segments addObject:segment6];
            [segmentMITextFields addObject:section6MI];
            [segmentNonMITextFields addObject:section6NonMI];
            [segmentNRTextFields addObject:section6NR];
        }
        
        for (i = 0; i < [segments count]; i++) {
            OSIROI* segment = [segments objectAtIndex:i];
            OSIROIMask *segmentMask = [segment ROIMaskForFloatVolumeData:floatVolumeData];
            NSTextField *MITextField = [segmentMITextFields objectAtIndex:i];
            NSTextField *nonMITextField = [segmentNonMITextFields objectAtIndex:i];
            NSTextField *noReflowTextField = [segmentNRTextFields objectAtIndex:i];
            
            float segmentRelativeSize = [[segment ROIFloatPixelDataForFloatVolumeData:floatVolumeData] floatCount];
            OSIROIFloatPixelData *segmentHealthyFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:[healthyMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData] autorelease];
            OSIROIFloatPixelData *segmentNoReflowFloatPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:[noReflowMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData] autorelease];
            float healthyRelativeSize = [segmentHealthyFloatPixelData floatCount];
            float noReflowRelativeSize = [segmentNoReflowFloatPixelData floatCount];
            [MITextField setStringValue:[NSString stringWithFormat:@"%.2f%%", 100.f - ((healthyRelativeSize + noReflowRelativeSize) / segmentRelativeSize)*100.f]];
            [nonMITextField setStringValue:[NSString stringWithFormat:@"%.2f%%", healthyRelativeSize*100.0f/segmentRelativeSize]];
            [noReflowTextField setStringValue:[NSString stringWithFormat:@"%.2f%%", noReflowRelativeSize*100.0f/segmentRelativeSize]];
        }

        // update the cursor on the histogram views
        // use a cutoff value stored in the epicardium ROI name
        OSIROI *outsideROI = [roiManager visibleEpicardialROI];
        NSArray *epiNameComponents = [[outsideROI name] componentsSeparatedByString:@";"];
        BOOL useThreshold = NO;
        float thresholdMin, thresholdMax;
        for (NSString *component in epiNameComponents) {
            if ([component hasPrefix:@"Infarct_threshold_"]) {
                useThreshold = [CMRSegTools parseRangeString:component prefix:@"Infarct_threshold_" min:&thresholdMin max:&thresholdMax];
            }
        }
        if (useThreshold) {
            [[self histogramView] setShowCursor:YES];
            [[self histogramView] setCursorValueMin:thresholdMin max:thresholdMax];
//            [self.histogramThresholdLabel setStringValue:[NSString stringWithFormat:@"%.2f-%.2f", thresholdMin, thresholdMax]];
            self.histogramRangeMinField.floatValue = thresholdMin;
            self.histogramRangeMaxField.floatValue = thresholdMax;
        } else {
            [[self histogramView] setShowCursor:NO];
        }
        
        OSIROI *importInfarctROI = [roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: MI by CMR42"];
        if (importInfarctROI) {
            ROI* osirixROI = [[importInfarctROI osiriXROIs] anyObject];
            if ([importCheckbox state]) {
                // we change it's name
                NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: MI by CMR42"];
                [newName appendString:@";YES"];
                [osirixROI setName:newName];
                [[NSNotificationCenter defaultCenter] postNotificationName:OsirixROIChangeNotification object:osirixROI userInfo: nil];
            }
            else{
                NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: MI by CMR42"];
                [newName appendString:@";NO"];
                [osirixROI setName:newName];
                [[NSNotificationCenter defaultCenter] postNotificationName:OsirixROIChangeNotification object:osirixROI userInfo: nil];
            }
        }
        
        OSIROI *importNRROI = [roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: NR by CMR42"];
        if (importNRROI) {
            ROI* osirixROI = [[importNRROI osiriXROIs] anyObject];
            if ([importCheckbox state]) {
                // we change it's name
                NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: NR by CMR42"];
                [newName appendString:@";YES"];
                [osirixROI setName:newName];
                [[NSNotificationCenter defaultCenter] postNotificationName:OsirixROIChangeNotification object:osirixROI userInfo: nil];
            }
            else{
                NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: NR by CMR42"];
                [newName appendString:@";NO"];
                [osirixROI setName:newName];
                [[NSNotificationCenter defaultCenter] postNotificationName:OsirixROIChangeNotification object:osirixROI userInfo: nil];
            }
        }
        
    } else {
        [[self histogramView] setShowCursor:NO];
    }
    
    [self _updateStatisticsLabels];
    [self _update2DLabels];
    [self _update3DLabels];
    [self _updateEndocardialSurfaceLabels];
    [self _updateTransmuralityLabels];
    
    // adjust the UI
    OSIROI *epicardiumROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];
    if (epicardiumROI) {
        [epicardiumButton setEnabled:NO];
    } else {
        [epicardiumButton setEnabled:YES];
    }

    OSIROI *endocardiumROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
    if (endocardiumROI) {
        [endocardiumButton setEnabled:NO];
    } else {
        [endocardiumButton setEnabled:YES];
    }
    
    OSIROI *LVRVROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"];
    if (LVRVROI || myocardiumROI == nil) {
        [LVRVButton setEnabled:NO];
    } else {
        [LVRVButton setEnabled:YES];
    }
    
    if (epicardiumROI || endocardiumROI || LVRVROI) {
        [quickDrawButton setEnabled:NO];
    } else {
        [quickDrawButton setEnabled:YES];
    }
    
    if (LVRVROI && myocardiumROI) {
        [drawSegmentsCheckbox setHidden:NO];
        [drawSegmentsLabel setHidden:NO];
    } else {
        [drawSegmentsCheckbox setHidden:YES];
        [drawSegmentsLabel setHidden:YES];
        [NRCheckbox setHidden:YES];
        [withNR setHidden:YES];
    }
    
    if (myocardiumROI) {
        [histogramThresholdCheckbox setEnabled:YES];
        [histogramThresholdTextLabel setTextColor:[NSColor controlBackgroundColor]];
        [runBEASButton setEnabled:YES];
        [growIncludeRegionButton setEnabled:YES];
        [includeROIButton setEnabled:YES];
        [excludeROIButton setEnabled:YES];
        [noReflowROIButton setEnabled:YES];
        [growNoReflowRegionButton setEnabled:YES];
        [popUpSegmentation setEnabled:YES];
    } else {
        [histogramThresholdCheckbox setEnabled:NO];
        [histogramThresholdTextLabel setTextColor:[NSColor grayColor]];
        [runBEASButton setEnabled:NO];
        [growIncludeRegionButton setEnabled:NO];
        [includeROIButton setEnabled:NO];
        [excludeROIButton setEnabled:NO];
        [noReflowROIButton setEnabled:NO];
        [growNoReflowRegionButton setEnabled:NO];
        [popUpSegmentation setEnabled:NO];
        [NRCheckbox setHidden:YES];
        [withNR setHidden:YES];
    }
    
    OSIROI *VLRVROI = [roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"];
    NSArray *LVRVNameComponents = [[VLRVROI name] componentsSeparatedByString:@";"];
    BOOL draw6Sections = YES;
    for (NSString *component in LVRVNameComponents) {
        if ([component hasPrefix:@"Number_of_sections_"]) {
            NSInteger sectionCount = [[component substringFromIndex:[@"Number_of_sections_" length]] integerValue];
            if (sectionCount == 4) {
                draw6Sections = NO;
            }
        }
    }

    if (draw6Sections) {
        [self.sectionNumberPopUpButton selectItemWithTitle:@"6"];
    } else {
        [self.sectionNumberPopUpButton selectItemWithTitle:@"4"];
    }
    
    OSIROI *epiROI = [roiManager visibleEpicardialROI];
    NSArray *epiNameComponents = [[epiROI name] componentsSeparatedByString:@";"];
    BOOL thresholdSegmenting = NO;
    for (NSString *component in epiNameComponents) {
        if ([component hasPrefix:@"Infarct_threshold_"]) {
            thresholdSegmenting = YES;
        }
    }
    if (thresholdSegmenting) {
        [histogramThresholdCheckbox setState: NSOnState];
//        [histogramThresholdLabel setHidden:NO];
        self.histogramRangeMinField.hidden = self.histogramRangeMaxField.hidden = self.histogramRangeToLabel.hidden = NO;
    } else {
        [histogramThresholdCheckbox setState: NSOffState];
//        [histogramThresholdLabel setHidden:YES];
        self.histogramRangeMinField.hidden = self.histogramRangeMaxField.hidden = self.histogramRangeToLabel.hidden = YES;
    }
    
    OSIROI *startAngleROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Infarct Start Angle"];
    OSIROI *endAngleROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Infarct End Angle"];
    if (myocardiumROI && !(startAngleROI || endAngleROI)) {
        [self.angleWiperButton setEnabled:YES];
    } else {
        [self.angleWiperButton setEnabled:NO];
    }
    
    OSIROI *clippedEndocardiumROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithName:@"clipped endocardium"];
    if (clippedEndocardiumROI) {
        [self.ESLLabel setHidden:NO];
        [self.ESLTextLabel setHidden:NO];
        [self.visibleOnlyLabel setHidden:NO];
        [self.minTransmurality setHidden:NO];
        [self.maxTransmurality setHidden:NO];
        [self.meanTransmurality setHidden:NO];
        [self.minTransmuralityLabel setHidden:NO];
        [self.maxTransmuralityLabel setHidden:NO];
        [self.meanTransmuralityLabel setHidden:NO];
    } else {
        [self.ESLLabel setHidden:YES];
        [self.ESLTextLabel setHidden:YES];
        [self.visibleOnlyLabel setHidden:YES];
        [self.minTransmurality setHidden:YES];
        [self.maxTransmurality setHidden:YES];
        [self.meanTransmurality setHidden:YES];
        [self.minTransmuralityLabel setHidden:YES];
        [self.maxTransmuralityLabel setHidden:YES];
        [self.meanTransmuralityLabel setHidden:YES];
    }

    NSArray *allClippedEndocardiumROIs = [[self.volumeWindow ROIManager] ROIsWithName:@"clipped endocardium"];
    if ([allClippedEndocardiumROIs count]) {
        [self.ESALabel setHidden:NO];
        [self.ESASurfaceLabel setHidden:NO];
        [self.ESATextLabel setHidden:NO];
    } else {
        [self.ESASurfaceLabel setHidden:YES];
        [self.ESALabel setHidden:YES];
        [self.ESATextLabel setHidden:YES];
    }
    
    OSIROI *remoteROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Remote_stddev_"];
    OSIROI *remoteROIFWHM = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: FWHMRegion"];
    OSIROI *remoteOutsideROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium;xSD_Segment_"];
    OSIROI *regionOutsideROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium;FWHM_Segment_"];
    OSIROI *regionROIFWHM3D = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: FWHM3D"];
    
    if (remoteROI && myocardiumROI) {
        float standardDevs = [[[remoteROI name] substringFromIndex:[@"CMRSegTools: Remote_stddev_" length]] floatValue];
        [self.stddevStepper setEnabled:YES];
        [self.stddevTextField setEnabled:YES];
        
        [self.stddevStepper setHidden:NO];
        [self.stddevTextField setHidden:NO];
        [self.stddevLabel setHidden:NO];
        [self.meanLabel setHidden:NO];
        [self.meanTextLabel setHidden:NO];
        [self.sigmaLabel setHidden:NO];
        [self.sigmaTextLabel setHidden:NO];
        [self.remoteThresholdLabel setHidden:NO];
        [self.thresholdTextLabel setHidden:NO];

        [self.meanLabelFWHM setHidden:YES];
        [self.meanTextLabelFWHM setHidden:YES];
        [self.ImaxLabelFWHM setHidden:YES];
        [self.ImaxTextLabelFWHM setHidden:YES];
        [self.remoteThresholdLabelFWHM setHidden:YES];
        [self.thresholdTextLabelFWHM setHidden:YES];
        [self.remoteMessage setHidden:YES];
        
        [self.segmentStepper setEnabled:NO];
        [self.segmentTextField setEnabled:NO];
        [self.withNR setHidden:YES];
        [self.NRCheckbox setHidden:YES];
        [self.segmentStepper setHidden:YES];
        [self.segmentTextField setHidden:YES];
        [self.segmentLabel setHidden:YES];

        self.displayedStatisticsLabels = CMRHistogramWindowSegmentationRegionStatisticsLabels;

        self.stddevStepper.integerValue = (NSUInteger)standardDevs;
        self.stddevTextField.integerValue = (NSUInteger)standardDevs;
        if ([roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"]) {
            if ([drawSegmentsCheckbox state])
            {
                [popUpSegmentation setAutoenablesItems:YES];
                
            }
            else{
                [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
                [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
                [popUpSegmentation setAutoenablesItems:NO];
            }
            
        }
        else
        {
            [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
            [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
            [popUpSegmentation setAutoenablesItems:NO];
        }
    }
    else if (remoteROIFWHM && myocardiumROI) {
        [self.meanLabelFWHM setHidden:NO];
        [self.meanTextLabelFWHM setHidden:NO];
        [self.ImaxLabelFWHM setHidden:NO];
        [self.ImaxTextLabelFWHM setHidden:NO];
        [self.remoteThresholdLabelFWHM setHidden:NO];
        [self.thresholdTextLabelFWHM setHidden:NO];
        
        [self.stddevStepper setEnabled:NO];
        [self.stddevTextField setEnabled:NO];
        
        [self.stddevStepper setHidden:YES];
        [self.stddevTextField setHidden:YES];
        [self.stddevLabel setHidden:YES];
        
        [self.segmentStepper setEnabled:NO];
        [self.segmentTextField setEnabled:NO];
        [self.withNR setHidden:YES];
        [self.NRCheckbox setHidden:YES];
        [self.segmentStepper setHidden:YES];
        [self.segmentTextField setHidden:YES];
        [self.segmentLabel setHidden:YES];
        [self.meanLabel setHidden:YES];
        [self.meanTextLabel setHidden:YES];
        [self.sigmaLabel setHidden:YES];
        [self.sigmaTextLabel setHidden:YES];
        [self.remoteThresholdLabel setHidden:YES];
        [self.thresholdTextLabel setHidden:YES];
        [self.remoteMessage setHidden:YES];

        self.displayedStatisticsLabels = CMRHistogramWindowSegmentationFWHMStatisticsLabels;

        if ([roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"]) {
            if ([drawSegmentsCheckbox state])
            {
                [popUpSegmentation setAutoenablesItems:YES];
                
            }
            else{
                [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
                [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
                [popUpSegmentation setAutoenablesItems:NO];
            }
            
        }
        else
        {
            [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
            [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
            [popUpSegmentation setAutoenablesItems:NO];
        }
        
    }
    else if (remoteOutsideROI && myocardiumROI) {
        NSArray *epiNameComponents = [[remoteOutsideROI name] componentsSeparatedByString:@";"];
        float standardDevs = 0;
        float seg = 0;
        for (NSString *component in epiNameComponents){
            if ([component hasPrefix:@"xSD_Segment_"])
            {
                seg = [[component substringFromIndex:[@"xSD_Segment_" length]] floatValue];
            }
            else if ([component hasPrefix:@"xSD_Remote_stddev_"])
            {
                standardDevs = [[component substringFromIndex:[@"xSD_Remote_stddev_" length]] floatValue];
            }
        }
        
        [self.stddevStepper setEnabled:YES];
        [self.stddevTextField setEnabled:YES];
        
        [self.stddevStepper setHidden:NO];
        [self.stddevTextField setHidden:NO];
        [self.stddevLabel setHidden:NO];
        [self.meanLabel setHidden:NO];
        [self.meanTextLabel setHidden:NO];
        [self.sigmaLabel setHidden:NO];
        [self.sigmaTextLabel setHidden:NO];
        [self.remoteThresholdLabel setHidden:NO];
        [self.thresholdTextLabel setHidden:NO];
        
        [self.meanLabelFWHM setHidden:YES];
        [self.meanTextLabelFWHM setHidden:YES];
        [self.ImaxLabelFWHM setHidden:YES];
        [self.ImaxTextLabelFWHM setHidden:YES];
        [self.remoteThresholdLabelFWHM setHidden:YES];
        [self.thresholdTextLabelFWHM setHidden:YES];
        [self.remoteMessage setHidden:YES];
        
        [self.segmentStepper setEnabled:YES];
        [self.segmentTextField setEnabled:YES];
        
        [self.segmentStepper setHidden:NO];
        [self.segmentTextField setHidden:NO];
        [self.segmentLabel setHidden:NO];
        [self.withNR setHidden:YES];
        [self.NRCheckbox setHidden:YES];
        self.stddevStepper.integerValue = (NSUInteger)standardDevs;
        self.stddevTextField.integerValue = (NSUInteger)standardDevs;
        self.segmentStepper.integerValue = (NSUInteger)seg;
        self.segmentTextField.integerValue = (NSUInteger)seg;

        self.displayedStatisticsLabels = CMRHistogramWindowSegmentationRegionStatisticsLabels;

        if ([roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"]) {
            if ([drawSegmentsCheckbox state])
            {
                [popUpSegmentation setAutoenablesItems:YES];
                
            }
            else{
                [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
                [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
                [popUpSegmentation setAutoenablesItems:NO];
            }
            
        }
        else
        {
            [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
            [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
            [popUpSegmentation setAutoenablesItems:NO];
        }
    }
    else if (regionOutsideROI && myocardiumROI) {
        NSArray *epiNameComponents = [[regionOutsideROI name] componentsSeparatedByString:@";"];
        float seg = 0;
        for (NSString *component in epiNameComponents){
            if ([component hasPrefix:@"FWHM_Segment_"])
            {
                seg = [[component substringFromIndex:[@"FWHM_Segment_" length]] floatValue];
            }
        }
        
        [self.stddevStepper setEnabled:NO];
        [self.stddevTextField setEnabled:NO];
        
        [self.stddevStepper setHidden:YES];
        [self.stddevTextField setHidden:YES];
        [self.stddevLabel setHidden:YES];
        [self.meanLabel setHidden:YES];
        [self.meanTextLabel setHidden:YES];
        [self.sigmaLabel setHidden:YES];
        [self.sigmaTextLabel setHidden:YES];
        [self.remoteThresholdLabel setHidden:YES];
        [self.thresholdTextLabel setHidden:YES];
        
        [self.meanLabelFWHM setHidden:NO];
        [self.meanTextLabelFWHM setHidden:NO];
        [self.ImaxLabelFWHM setHidden:NO];
        [self.ImaxTextLabelFWHM setHidden:NO];
        [self.remoteThresholdLabelFWHM setHidden:NO];
        [self.thresholdTextLabelFWHM setHidden:NO];
        [self.remoteMessage setHidden:YES];
        [self.withNR setHidden:YES];
        [self.NRCheckbox setHidden:YES];
        [self.segmentStepper setEnabled:YES];
        [self.segmentTextField setEnabled:YES];
        
        [self.segmentStepper setHidden:NO];
        [self.segmentTextField setHidden:NO];
        [self.segmentLabel setHidden:NO];
        
        self.segmentStepper.integerValue = (NSUInteger)seg;
        self.segmentTextField.integerValue = (NSUInteger)seg;

        self.displayedStatisticsLabels = CMRHistogramWindowSegmentationFWHMStatisticsLabels;

        if ([roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"]) {
            if ([drawSegmentsCheckbox state])
            {
                [popUpSegmentation setAutoenablesItems:YES];
                
            }
            else{
                [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
                [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
                [popUpSegmentation setAutoenablesItems:NO];
            }
            
        }
        else
        {
            [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
            [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
            [popUpSegmentation setAutoenablesItems:NO];
        }
    }
    else if (regionROIFWHM3D) {
        [remoteMessage setHidden:YES];
        [self.NRCheckbox setHidden:YES];
        [self.withNR setHidden:YES];
        [self.stddevStepper setEnabled:NO];
        [self.stddevTextField setEnabled:NO];
        
        [self.stddevStepper setHidden:YES];
        [self.stddevTextField setHidden:YES];
        [self.stddevLabel setHidden:YES];
        [self.meanLabel setHidden:YES];
        [self.meanTextLabel setHidden:YES];
        [self.sigmaLabel setHidden:YES];
        [self.sigmaTextLabel setHidden:YES];
        [self.remoteThresholdLabel setHidden:YES];
        [self.thresholdTextLabel setHidden:YES];
        
        [self.meanLabelFWHM setHidden:YES];
        [self.meanTextLabelFWHM setHidden:YES];
        [self.ImaxLabelFWHM setHidden:YES];
        [self.ImaxTextLabelFWHM setHidden:YES];
        [self.remoteThresholdLabelFWHM setHidden:YES];
        [self.thresholdTextLabelFWHM setHidden:YES];
        [self.remoteMessage setHidden:YES];
        [self.popUpSegmentation setEnabled:YES];
        [self.segmentStepper setEnabled:NO];
        [self.segmentTextField setEnabled:NO];
        [self.segmentStepper setHidden:YES];
        [self.segmentTextField setHidden:YES];
        [self.segmentLabel setHidden:YES];

        self.displayedStatisticsLabels = CMRHistogramWindowSegmentationNoStatisticsLabels;
    }
    else if (myocardiumROI && ([[self.popUpSegmentation titleOfSelectedItem] isEqualToString:@"Hsu modified"] || [[self.volumeWindow ROIManager]firstVisibleROIWithNamePrefix:@"Hsu: No-reflow;"])) {
        [self.withNR setHidden:NO];
        [self.NRCheckbox setHidden:NO];
        
        [self.stddevStepper setEnabled:NO];
        [self.stddevTextField setEnabled:NO];
        
        [self.stddevStepper setHidden:YES];
        [self.stddevTextField setHidden:YES];
        [self.stddevLabel setHidden:YES];
        [self.meanLabel setHidden:YES];
        [self.meanTextLabel setHidden:YES];
        [self.sigmaLabel setHidden:YES];
        [self.sigmaTextLabel setHidden:YES];
        [self.remoteThresholdLabel setHidden:YES];
        [self.thresholdTextLabel setHidden:YES];
        
        [self.meanLabelFWHM setHidden:YES];
        [self.meanTextLabelFWHM setHidden:YES];
        [self.ImaxLabelFWHM setHidden:YES];
        [self.ImaxTextLabelFWHM setHidden:YES];
        [self.remoteThresholdLabelFWHM setHidden:YES];
        [self.thresholdTextLabelFWHM setHidden:YES];
        [self.remoteMessage setHidden:YES];
        [self.popUpSegmentation setEnabled:YES];
        [self.segmentStepper setEnabled:NO];
        [self.segmentTextField setEnabled:NO];
        [self.segmentStepper setHidden:YES];
        [self.segmentTextField setHidden:YES];
        [self.segmentLabel setHidden:YES];

        self.displayedStatisticsLabels = CMRHistogramWindowSegmentationNoStatisticsLabels;

        if ([roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"]) {
            if ([drawSegmentsCheckbox state])
            {
                [popUpSegmentation setAutoenablesItems:YES];
                
            }
            else{
                [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
                [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
                [popUpSegmentation setAutoenablesItems:NO];
            }
            
        }
        else
        {
            [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
            [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
            [popUpSegmentation setAutoenablesItems:NO];
        }
    }
    else if (myocardiumROI && ([[self.popUpSegmentation titleOfSelectedItem] isEqualToString:@"HMRF EM"] || [[self.volumeWindow ROIManager]firstVisibleROIWithNamePrefix:@"hmrf: No-reflow;"])) {
        [self.withNR setHidden:NO];
        [self.NRCheckbox setHidden:NO];
        
        [self.stddevStepper setEnabled:NO];
        [self.stddevTextField setEnabled:NO];
        
        [self.stddevStepper setHidden:YES];
        [self.stddevTextField setHidden:YES];
        [self.stddevLabel setHidden:YES];
        [self.meanLabel setHidden:YES];
        [self.meanTextLabel setHidden:YES];
        [self.sigmaLabel setHidden:YES];
        [self.sigmaTextLabel setHidden:YES];
        [self.remoteThresholdLabel setHidden:YES];
        [self.thresholdTextLabel setHidden:YES];
        
        [self.meanLabelFWHM setHidden:YES];
        [self.meanTextLabelFWHM setHidden:YES];
        [self.ImaxLabelFWHM setHidden:YES];
        [self.ImaxTextLabelFWHM setHidden:YES];
        [self.remoteThresholdLabelFWHM setHidden:YES];
        [self.thresholdTextLabelFWHM setHidden:YES];
        [self.remoteMessage setHidden:YES];
        [self.popUpSegmentation setEnabled:YES];
        [self.segmentStepper setEnabled:NO];
        [self.segmentTextField setEnabled:NO];
        [self.segmentStepper setHidden:YES];
        [self.segmentTextField setHidden:YES];
        [self.segmentLabel setHidden:YES];

        self.displayedStatisticsLabels = CMRHistogramWindowSegmentationNoStatisticsLabels;

        if ([roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"]) {
            if ([drawSegmentsCheckbox state])
            {
                [popUpSegmentation setAutoenablesItems:YES];
                
            }
            else{
                [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
                [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
                [popUpSegmentation setAutoenablesItems:NO];
            }
            
        }
        else
        {
            [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
            [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
            [popUpSegmentation setAutoenablesItems:NO];
        }
    }
    //_______ADDED_BY_WAROMERO(28/07/2015)_______
    else if (myocardiumROI && ([[self.popUpSegmentation titleOfSelectedItem] isEqualToString:@"HMRF (alpha version)"] || [[self.volumeWindow ROIManager]firstVisibleROIWithNamePrefix:@"hmrf: No-reflow;"])) {
        [self.withNR setHidden:NO];
        [self.NRCheckbox setHidden:NO];
        
        [self.stddevStepper setEnabled:NO];
        [self.stddevTextField setEnabled:NO];
        
        [self.stddevStepper setHidden:YES];
        [self.stddevTextField setHidden:YES];
        [self.stddevLabel setHidden:YES];
        [self.meanLabel setHidden:YES];
        [self.meanTextLabel setHidden:YES];
        [self.sigmaLabel setHidden:YES];
        [self.sigmaTextLabel setHidden:YES];
        [self.remoteThresholdLabel setHidden:YES];
        [self.thresholdTextLabel setHidden:YES];
        
        [self.meanLabelFWHM setHidden:YES];
        [self.meanTextLabelFWHM setHidden:YES];
        [self.ImaxLabelFWHM setHidden:YES];
        [self.ImaxTextLabelFWHM setHidden:YES];
        [self.remoteThresholdLabelFWHM setHidden:YES];
        [self.thresholdTextLabelFWHM setHidden:YES];
        [self.remoteMessage setHidden:YES];
        [self.popUpSegmentation setEnabled:YES];
        [self.segmentStepper setEnabled:NO];
        [self.segmentTextField setEnabled:NO];
        [self.segmentStepper setHidden:YES];
        [self.segmentTextField setHidden:YES];
        [self.segmentLabel setHidden:YES];
        
        self.displayedStatisticsLabels = CMRHistogramWindowSegmentationNoStatisticsLabels;
        
        if ([roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"]) {
            if ([drawSegmentsCheckbox state])
            {
                [popUpSegmentation setAutoenablesItems:YES];
                
            }
            else{
                [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
                [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
                [popUpSegmentation setAutoenablesItems:NO];
            }
            
        }
        else
        {
            [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
            [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
            [popUpSegmentation setAutoenablesItems:NO];
        }
    }
    else if (myocardiumROI) {
        [self.stddevStepper setEnabled:NO];
        [self.stddevTextField setEnabled:NO];
        
        [self.stddevStepper setHidden:YES];
        [self.stddevTextField setHidden:YES];
        [self.stddevLabel setHidden:YES];
        [self.meanLabel setHidden:YES];
        [self.meanTextLabel setHidden:YES];
        [self.sigmaLabel setHidden:YES];
        [self.sigmaTextLabel setHidden:YES];
        [self.remoteThresholdLabel setHidden:YES];
        [self.thresholdTextLabel setHidden:YES];
        
        [self.meanLabelFWHM setHidden:YES];
        [self.meanTextLabelFWHM setHidden:YES];
        [self.ImaxLabelFWHM setHidden:YES];
        [self.ImaxTextLabelFWHM setHidden:YES];
        [self.remoteThresholdLabelFWHM setHidden:YES];
        [self.thresholdTextLabelFWHM setHidden:YES];
        [self.remoteMessage setHidden:YES];
        [self.popUpSegmentation setEnabled:YES];
        [self.withNR setHidden:YES];
        [self.segmentStepper setEnabled:NO];
        [self.segmentTextField setEnabled:NO];
        [self.segmentStepper setHidden:YES];
        [self.segmentTextField setHidden:YES];
        [self.segmentLabel setHidden:YES];

        self.displayedStatisticsLabels = CMRHistogramWindowSegmentationNoStatisticsLabels;

        if ([roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"]) {
            if ([drawSegmentsCheckbox state])
            {
                [popUpSegmentation setAutoenablesItems:YES];
                
            }
            else{
                [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
                [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
                [popUpSegmentation setAutoenablesItems:NO];
            }
            
        }
        else
        {
            [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
            [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
            [popUpSegmentation setAutoenablesItems:NO];
        }
    }
    else {
        [self.stddevStepper setEnabled:NO];
        [self.stddevTextField setEnabled:NO];
        
        [self.stddevStepper setHidden:YES];
        [self.stddevTextField setHidden:YES];
        [self.stddevLabel setHidden:YES];
        [self.meanLabel setHidden:YES];
        [self.meanTextLabel setHidden:YES];
        [self.sigmaLabel setHidden:YES];
        [self.sigmaTextLabel setHidden:YES];
        [self.remoteThresholdLabel setHidden:YES];
        [self.thresholdTextLabel setHidden:YES];
        
        [self.withNR setHidden:YES];
        [self.NRCheckbox setHidden:YES];
        [self.meanLabelFWHM setHidden:YES];
        [self.meanTextLabelFWHM setHidden:YES];
        [self.ImaxLabelFWHM setHidden:YES];
        [self.ImaxTextLabelFWHM setHidden:YES];
        [self.remoteThresholdLabelFWHM setHidden:YES];
        [self.thresholdTextLabelFWHM setHidden:YES];
        [self.remoteMessage setHidden:YES];
        [self.popUpSegmentation setEnabled:NO];
        [self.segmentStepper setEnabled:NO];
        [self.segmentTextField setEnabled:NO];
        [self.segmentStepper setHidden:YES];
        [self.segmentTextField setHidden:YES];
        [self.segmentLabel setHidden:YES];

        self.displayedStatisticsLabels = CMRHistogramWindowSegmentationNoStatisticsLabels;

        if ([roiManager firstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"]) {
            if ([drawSegmentsCheckbox state])
            {
                [popUpSegmentation setAutoenablesItems:YES];
                
            }
            else{
                [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
                [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
                [popUpSegmentation setAutoenablesItems:NO];
            }
            
        }
        else
        {
            [[popUpSegmentation itemAtIndex:3]setEnabled:NO];
            [[popUpSegmentation itemAtIndex:5]setEnabled:NO];
            [popUpSegmentation setAutoenablesItems:NO];
        }
    }
}

- (void)_updateEndocardialSurfaceLabels
{
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];

    OSIROI *lengthEndocardiumROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithName:@"clipped endocardium"];
    OSIROI *lengthWholeEndocardiumROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
    N3BezierPath *path = [lengthEndocardiumROI performSelector:@selector(path)]; // perform selector because I forgot to hook up the accessor for bezierPath
    N3BezierPath *wholePath = [lengthWholeEndocardiumROI bezierPath];
    
    float pathLength = [path length];
    float wholePathLength = [wholePath length];
    if (wholePathLength) {
        [self.ESLLabel setStringValue:[NSString stringWithFormat:@"%.0f%%", (pathLength/wholePathLength) * 100.0]];
    }
    
    NSInteger movieIndex = [[self.volumeWindow viewerController] curMovieIndex];
    NSUInteger i;
    float totalEndocardialLength = 0;
    float totalInfactLength = 0;
    
    for (i = 0; i < [[[[self.volumeWindow viewerController] imageView] dcmPixList] count]; i++) {
        lengthEndocardiumROI = [[self.volumeWindow ROIManager] CMRFirstROIWithNamePrefix:@"clipped endocardium" movieIndex:movieIndex pixIndex:i];
        lengthWholeEndocardiumROI = [[self.volumeWindow ROIManager] endocardialROIAtMovieIndex:movieIndex pixIndex:i];
        path = [lengthEndocardiumROI performSelector:@selector(path)]; // perform selector because I forgot to hook up the accessor for bezierPath
        wholePath = [lengthWholeEndocardiumROI bezierPath];
        pathLength = [path length];
        wholePathLength = [wholePath length];
        
        if (wholePathLength) {
            totalEndocardialLength += wholePathLength;
            totalInfactLength += pathLength;
        }
    }
    
    if (totalEndocardialLength) {
        [self.ESALabel setStringValue:[NSString stringWithFormat:@"%.0f%%", (totalInfactLength/totalEndocardialLength) * 100.0]];
    }
    
    NSArray *allROIs = [[self.volumeWindow ROIManager] ROIsWithName:@"clipped endocardium"];
    double totalLength = 0;
    for (OSIROI* roi in allROIs) {
        path = [roi performSelector:@selector(path)]; // perform selector because I forgot to hook up the accessor for bezierPath
        totalLength += [path length] * 0.1;
    }
    
    [self.ESASurfaceLabel setStringValue:[NSString stringWithFormat:@"%.2fcm2", totalLength * [floatVolumeData pixelSpacingZ] * 0.1]];
}

- (void)_updateTransmuralityLabels
{
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];

    OSIROI *infactStartAngleROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Infarct Start Angle"];
    OSIROI *infactEndAngleROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Infarct End Angle"];
    OSIROI *lengthEndocardiumROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithName:@"clipped endocardium"];
    OSIROI *myocardiumROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithName:@"myocardium"];
    OSIROI *nonWedgeClippedSegementedROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithName:@"nonWedgeClippedSegmented"];
    
    OSIROIMask *myocardiumMask = [myocardiumROI ROIMaskForFloatVolumeData:[myocardiumROI homeFloatVolumeData]];
    OSIROIMask *nonWedgeClippedSegementedMask = [nonWedgeClippedSegementedROI ROIMaskForFloatVolumeData:[nonWedgeClippedSegementedROI homeFloatVolumeData]];
    
    if (infactStartAngleROI == nil || infactEndAngleROI == nil || lengthEndocardiumROI == nil || myocardiumROI == nil || nonWedgeClippedSegementedROI == nil ||
        myocardiumMask == nil || nonWedgeClippedSegementedMask == nil) {
        return;
    }
    
    N3Vector normalVector = N3VectorApplyTransformToDirectionalVector(N3VectorMake(0, 0, 1), N3AffineTransformInvert(floatVolumeData.volumeTransform));
    N3Vector startVector0 = N3VectorZero;
    N3Vector startVector1 = N3VectorZero;
    N3Vector endVector0 = N3VectorZero;
    N3Vector endVector1 = N3VectorZero;
    
    [[infactStartAngleROI bezierPath] elementAtIndex:0 control1:NULL control2:NULL endpoint:&startVector0];
    [[infactStartAngleROI bezierPath] elementAtIndex:1 control1:NULL control2:NULL endpoint:&startVector1];
    
    [[infactEndAngleROI bezierPath] elementAtIndex:0 control1:NULL control2:NULL endpoint:&endVector0];
    [[infactEndAngleROI bezierPath] elementAtIndex:1 control1:NULL control2:NULL endpoint:&endVector1];
    
    // find out if we are using the wide angle
    BOOL useWideAngle = NO;
    if (N3VectorDotProduct(N3VectorCrossProduct(N3VectorSubtract(startVector1, startVector0), N3VectorSubtract(endVector1, endVector0)), normalVector) > 0) {
        useWideAngle = YES;
    } else {
        useWideAngle = NO;
    }

    CGFloat minTransmuralityValue;
    CGFloat maxTransmuralityValue;
    CGFloat meanTransmuralityValue;
    
    [[self class] _infarctTransmuralityForMyocardiumMask:myocardiumMask infarctMask:nonWedgeClippedSegementedMask
                                          firstLineStart:startVector0 firstLineEnd:startVector1
                                         secondLineStart:endVector0 secondLineEnd:endVector1
                                            useWideAngle:useWideAngle stepAngle:3.6*(M_PI/180.0)
                                         sectorLineStart:N3VectorZero sectorLineEnd:N3VectorZero sectorCount:0 sector:0
                                         volumeTransform:floatVolumeData.volumeTransform
                                        minTransmurality:&minTransmuralityValue maxTransmurality:&maxTransmuralityValue meanTransmurality:&meanTransmuralityValue];
    
    [self.minTransmurality setStringValue:[NSString stringWithFormat:@"%.0f%%", minTransmuralityValue * 100.0]];
    [self.maxTransmurality setStringValue:[NSString stringWithFormat:@"%.0f%%", maxTransmuralityValue * 100.0]];
    [self.meanTransmurality setStringValue:[NSString stringWithFormat:@"%.0f%%", meanTransmuralityValue * 100.0]];
}


- (void)_updateStatisticsLabels
{
    // first update the menu;
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    BOOL drawSections = NO;
    BOOL draw6Sections = YES;

    OSIROI *LVRVROI = [roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"];
    if (LVRVROI && [[LVRVROI bezierPath] elementCount] == 2) {
        drawSections = YES;
        NSArray *LVRVNameComponents = [[LVRVROI name] componentsSeparatedByString:@";"];
        for (NSString *component in LVRVNameComponents) {
            if ([component hasPrefix:@"Number_of_sections_"]) {
                NSInteger sectionCount = [[component substringFromIndex:[@"Number_of_sections_" length]] integerValue];
                if (sectionCount == 4) {
                    draw6Sections = NO;
                }
            }
        }
    }
    
    NSMenu *menu = [self.statisticsSelectorPopUp menu];
    if (drawSections) { // add  all the sector menu items
        if ([self.sector1MenuItem menu] == nil) {
            [menu addItem:self.sector1MenuItem];
        }
        if ([self.sector2MenuItem menu] == nil) {
            [menu addItem:self.sector2MenuItem];
        }
        if ([self.sector3MenuItem menu] == nil) {
            [menu addItem:self.sector3MenuItem];
        }
        if ([self.sector4MenuItem menu] == nil) {
            [menu addItem:self.sector4MenuItem];
        }
        if (draw6Sections) {
            if ([self.sector5MenuItem menu] == nil) {
                [menu addItem:self.sector5MenuItem];
            }
            if ([self.sector6MenuItem menu] == nil) {
                [menu addItem:self.sector6MenuItem];
            }
        } else {
            if ([self.sector5MenuItem menu]) {
                if ([self.sector5MenuItem state] != NSOffState) {
                    [self.statisticsSelectorPopUp selectItemAtIndex:0];
                }
                [menu removeItem:self.sector5MenuItem];
            }
            if ([self.sector6MenuItem menu]) {
                if ([self.sector6MenuItem state] != NSOffState) {
                    [self.statisticsSelectorPopUp selectItemAtIndex:0];
                }
                [menu removeItem:self.sector6MenuItem];
            }
        }
    } else {
        if ([self.sector1MenuItem menu]) {
            if ([self.sector1MenuItem state] != NSOffState) {
                [self.statisticsSelectorPopUp selectItemAtIndex:0];
            }
            [menu removeItem:self.sector1MenuItem];
        }
        if ([self.sector2MenuItem menu]) {
            if ([self.sector2MenuItem state] != NSOffState) {
                [self.statisticsSelectorPopUp selectItemAtIndex:0];
            }
            [menu removeItem:self.sector2MenuItem];
        }
        if ([self.sector3MenuItem menu]) {
            if ([self.sector3MenuItem state] != NSOffState) {
                [self.statisticsSelectorPopUp selectItemAtIndex:0];
            }
            [menu removeItem:self.sector3MenuItem];
        }
        if ([self.sector4MenuItem menu]) {
            if ([self.sector4MenuItem state] != NSOffState) {
                [self.statisticsSelectorPopUp selectItemAtIndex:0];
            }
            [menu removeItem:self.sector4MenuItem];
        }
        if ([self.sector5MenuItem menu]) {
            if ([self.sector5MenuItem state] != NSOffState) {
                [self.statisticsSelectorPopUp selectItemAtIndex:0];
            }
            [menu removeItem:self.sector5MenuItem];
        }
        if ([self.sector6MenuItem menu]) {
            if ([self.sector6MenuItem state] != NSOffState) {
                [self.statisticsSelectorPopUp selectItemAtIndex:0];
            }
            [menu removeItem:self.sector6MenuItem];
        }
    }
    
    OSIROIFloatPixelData *floatPixelData = [self _pixelDataForStatisticsSelectorTag:[[self.statisticsSelectorPopUp selectedItem] tag]];

    [myocardiumArea setStringValue:[NSString stringWithFormat:@"%.2fcm2", [floatVolumeData pixelSpacingX]*[floatVolumeData pixelSpacingY]*(float)[floatPixelData floatCount]/100.0f]];
    [myocardiumMean setStringValue:[NSString stringWithFormat:@"%.2f", [floatPixelData intensityMean]]];
    [myocardiumStddev setStringValue:[NSString stringWithFormat:@"%.2f", [floatPixelData intensityStandardDeviation]]];
    [myocardiumIQR setStringValue:[NSString stringWithFormat:@"%.2f", [floatPixelData intensityInterQuartileRange]]];
    [myocardiumMedian setStringValue:[NSString stringWithFormat:@"%.2f", [floatPixelData intensityMedian]]];
    [myocardiumMin setStringValue:[NSString stringWithFormat:@"%.2f", [floatPixelData intensityMin]]];
    [myocardiumMax setStringValue:[NSString stringWithFormat:@"%.2f", [floatPixelData intensityMax]]];
}

- (OSIROIFloatPixelData *)_pixelDataForStatisticsSelectorTag:(StatisticsSelectorTag)tag
{
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    OSIROI *roi = nil;
    OSIROIMask *mask = nil;
    
    switch (tag) {
        case MyocardiumSelectorTag:
            roi = [roiManager CMRFirstVisibleROIWithName:@"wedgeClippedMyocardium"];
            mask = [roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]];
            roi = [roiManager CMRFirstVisibleROIWithName:@"myocardium"]; // so that roi is initialized for sure
            break;
        case MISelectorTag:
            roi = [roiManager CMRFirstVisibleROIWithName:@"segmented"];
            mask = [roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]];
            break;
        case NonMISelectorTag:
            roi = [roiManager CMRFirstVisibleROIWithName:@"wedgeClippedMyocardium"];
            mask = [roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]];
            roi = [roiManager CMRFirstVisibleROIWithName:@"segmented"];
            if (roi) {
                mask = [mask ROIMaskBySubtractingMask:[roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]]];
            }
            roi = [roiManager CMRFirstVisibleROIWithName:@"no-reflow"];
            if (roi) {
                mask = [mask ROIMaskBySubtractingMask:[roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]]];
            }
            roi = [roiManager CMRFirstVisibleROIWithName:@"myocardium"]; // so that roi is initialized for sure
            break;
        case NoReflowSelectorTag:
            roi = [roiManager CMRFirstVisibleROIWithName:@"no-reflow"];
            mask = [roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]];
            break;
        case Sector1SelectorTag:
            roi = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 1"];
            mask = [roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]];
            break;
        case Sector2SelectorTag:
            roi = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 2"];
            mask = [roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]];
            break;
        case Sector3SelectorTag:
            roi = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 3"];
            mask = [roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]];
            break;
        case Sector4SelectorTag:
            roi = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 4"];
            mask = [roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]];
            break;
        case Sector5SelectorTag:
            roi = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 5"];
            mask = [roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]];
            break;
        case Sector6SelectorTag:
            roi = [roiManager CMRFirstVisibleROIWithName:@"myocardium segment 6"];
            mask = [roi ROIMaskForFloatVolumeData:[roi homeFloatVolumeData]];
            break;
        default:
            assert(0);
            break;
    }
    
    if ([mask maskRunCount]) {
        return [[[OSIROIFloatPixelData alloc] initWithROIMask:mask floatVolumeData:[roi homeFloatVolumeData]] autorelease];
    }
    return nil;
}

- (void)_update2DLabels
{
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    BOOL CMR42EmulationMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"CMR42EmulationMode"];
    
    OSIROI *myocardiumROI = [roiManager CMRFirstVisibleROIWithName:@"myocardium"];
    OSIROI *segmentedROI = [roiManager CMRFirstVisibleROIWithName:@"segmented"];
    OSIROI *noReflowRoi = [roiManager CMRFirstVisibleROIWithName:@"no-reflow"];
    
    if (CMR42EmulationMode && myocardiumROI) {
        floatVolumeData = [myocardiumROI homeFloatVolumeData];
    }

    OSIROIMask *myocardium2DMask = [myocardiumROI ROIMaskForFloatVolumeData:floatVolumeData];
    OSIROIMask *segmented2DMask = [segmentedROI ROIMaskForFloatVolumeData:floatVolumeData];
    OSIROIMask *noReflow2DMask = [noReflowRoi ROIMaskForFloatVolumeData:floatVolumeData];

    double myocardiumCount = (double)[myocardium2DMask maskIndexCount];
    double MICount = (double)[segmented2DMask maskIndexCount];
    double noReflowCount = (double)[noReflow2DMask maskIndexCount];
    double nonMICount = myocardiumCount - (MICount + noReflowCount);
    
    if (myocardiumCount > 0) {
        [self.percentMI2D setStringValue:[NSString stringWithFormat:@"%.2f", (MICount/myocardiumCount)*100.0]];
        [self.percentNR2D setStringValue:[NSString stringWithFormat:@"%.2f", (noReflowCount/myocardiumCount)*100.0]];
        [self.percentNonMI2D setStringValue:[NSString stringWithFormat:@"%.2f", (nonMICount/myocardiumCount)*100.0]];
    } else {
        [self.percentMI2D setStringValue:@""];
        [self.percentNR2D setStringValue:@""];
        [self.percentNonMI2D setStringValue:@""];
    }
    
    [self.areaMI2D setStringValue:[NSString stringWithFormat:@"%.2f", MICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * 0.01]];
    [self.areaNR2D setStringValue:[NSString stringWithFormat:@"%.2f", noReflowCount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * 0.01]];
    [self.areaNonMI2D setStringValue:[NSString stringWithFormat:@"%.2f", nonMICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * 0.01]];
    
    [self.volumeMI2D setStringValue:[NSString stringWithFormat:@"%.2f", MICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001]];
    [self.volumeNR2D setStringValue:[NSString stringWithFormat:@"%.2f", noReflowCount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001]];
    [self.volumeNonMI2D setStringValue:[NSString stringWithFormat:@"%.2f", nonMICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001]];
    
    [self.weightMI2D setStringValue:[NSString stringWithFormat:@"%.2f", MICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001 * 1.05]];
    [self.weightNR2D setStringValue:[NSString stringWithFormat:@"%.2f", noReflowCount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001 * 1.05]];
    [self.weightNonMI2D setStringValue:[NSString stringWithFormat:@"%.2f", nonMICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001 * 1.05]];
}

- (void)_update3DLabels
{
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    BOOL CMR42EmulationMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"CMR42EmulationMode"];
    
    OSIROI *myocardiumROI = [roiManager CMRFirstVisibleROIWithName:@"myocardium"];
    if (CMR42EmulationMode && myocardiumROI) {
        floatVolumeData = [myocardiumROI homeFloatVolumeData];
    }
    
    NSArray *myocardiumROIs = [roiManager ROIsWithName:@"myocardium"];
    NSArray *segmentedROIs = [roiManager ROIsWithName:@"segmented"];
    NSArray *noReflowRois = [roiManager ROIsWithName:@"no-reflow"];
    
    OSIROIMask *myocardium3DMask = [OSIROIMask ROIMask];
    for (OSIROI *roi in myocardiumROIs) {
        myocardium3DMask = [myocardium3DMask ROIMaskByUnioningWithMask:[roi ROIMaskForFloatVolumeData:floatVolumeData]];
    }
    
    OSIROIMask *segmented3DMask = [OSIROIMask ROIMask];
    for (OSIROI *roi in segmentedROIs) {
        segmented3DMask = [segmented3DMask ROIMaskByUnioningWithMask:[roi ROIMaskForFloatVolumeData:floatVolumeData]];
    }
    
    OSIROIMask *noReflow3DMask = [OSIROIMask ROIMask];
    for (OSIROI *roi in noReflowRois) {
        noReflow3DMask = [noReflow3DMask ROIMaskByUnioningWithMask:[roi ROIMaskForFloatVolumeData:floatVolumeData]];
    }
    
    double myocardiumCount = (double)[myocardium3DMask maskIndexCount];
    double MICount = (double)[segmented3DMask maskIndexCount];
    double noReflowCount = (double)[noReflow3DMask maskIndexCount];
    double nonMICount = myocardiumCount - (MICount + noReflowCount);
    
    if (myocardiumCount > 0) {
        [self.percentMI3D setStringValue:[NSString stringWithFormat:@"%.2f", (MICount/myocardiumCount)*100.0]];
        [self.percentNR3D setStringValue:[NSString stringWithFormat:@"%.2f", (noReflowCount/myocardiumCount)*100.0]];
        [self.percentNonMI3D setStringValue:[NSString stringWithFormat:@"%.2f", (nonMICount/myocardiumCount)*100.0]];
    } else {
        [self.percentMI3D setStringValue:@""];
        [self.percentNR3D setStringValue:@""];
        [self.percentNonMI3D setStringValue:@""];
    }
    
    [self.areaMI3D setStringValue:[NSString stringWithFormat:@"%.2f", MICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * 0.01]];
    [self.areaNR3D setStringValue:[NSString stringWithFormat:@"%.2f", noReflowCount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * 0.01]];
    [self.areaNonMI3D setStringValue:[NSString stringWithFormat:@"%.2f", nonMICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * 0.01]];
    
    [self.volumeMI3D setStringValue:[NSString stringWithFormat:@"%.2f", MICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001]];
    [self.volumeNR3D setStringValue:[NSString stringWithFormat:@"%.2f", noReflowCount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001]];
    [self.volumeNonMI3D setStringValue:[NSString stringWithFormat:@"%.2f", nonMICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001]];
    
    [self.weightMI3D setStringValue:[NSString stringWithFormat:@"%.2f", MICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001 * 1.05]];
    [self.weightNR3D setStringValue:[NSString stringWithFormat:@"%.2f", noReflowCount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001 * 1.05]];
    [self.weightNonMI3D setStringValue:[NSString stringWithFormat:@"%.2f", nonMICount * floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001 * 1.05]];
}

- (void)_volumeWindowDidCloseNotification:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self close];
}

- (void)_volumeWindowDidChangeDataNotification:(NSNotification *)notification
{
    [[self.volumeWindow viewerController] setWindowTitle:[self.volumeWindow viewerController]]; // just a little hack to make sure the window title is set
    [[self window] setTitle:[NSString stringWithFormat:@"SegTools: %@",[[[self.volumeWindow viewerController] window] title]]];
}

- (void)_startStep:(CMRSegToolsStep *)step  {
    [self _startStep:step sticky:nil];
}

- (void)_startStep:(CMRSegToolsStep *)step sticky:(NSButton*)button
{
    if (button != currentStickyButton)
        currentStickyButton.state = NSOffState;

    if (activeStep) {
        if (activeStep.finished == NO)
            [activeStep cancel];
        activeStep.delegate = nil;
        [activeStep release];
        activeStep = nil;
    }
    
    if (step) {
        activeStep = [step retain];
        activeStep.delegate = self;
        [activeStep start];
    }
    
    currentStickyButton = button; // no, no retaining here
}

- (void)removeROI:(NSString*)tool
{
    NSArray *ROIarray = [[self.volumeWindow ROIManager] ROIs];
    if ([ROIarray count]>0) {
        for (OSIROI *roi in ROIarray) {
            if ([[roi name] hasPrefix:@"CMRSegTools: FWHM3D"]) {
                [[self.volumeWindow ROIManager] removeROI:roi];
                [[self.volumeWindow viewerController]deleteROI:[[roi osiriXROIs]anyObject]];
            }
            if ([[roi name] hasPrefix:@"Hsu"]) {
                [[self.volumeWindow ROIManager] removeROI:roi];
                [[self.volumeWindow viewerController]deleteROI:[[roi osiriXROIs]anyObject]];
            }
            if ([[roi name] hasPrefix:@"Hsu: No-reflow"]) {
                [[self.volumeWindow ROIManager] removeROI:roi];
                [[self.volumeWindow viewerController]deleteROI:[[roi osiriXROIs]anyObject]];
            }
            if ([[roi name] hasPrefix:@"hmrfMask"]) {
                [[self.volumeWindow ROIManager] removeROI:roi];
                [[self.volumeWindow viewerController]deleteROI:[[roi osiriXROIs]anyObject]];
            }
            if ([[roi name] hasPrefix:@"hmrf: No-reflow"]) {
                [[self.volumeWindow ROIManager] removeROI:roi];
                [[self.volumeWindow viewerController]deleteROI:[[roi osiriXROIs]anyObject]];
            }
            if ([[roi name] hasPrefix:@"CMRSegTools: No-reflow"]) {
                [[self.volumeWindow ROIManager] removeROI:roi];
                [[self.volumeWindow viewerController]deleteROI:[[roi osiriXROIs]anyObject]];
            }
            if ([[roi name] hasPrefix:@"segmented"]) {
                [[self.volumeWindow ROIManager] removeROI:roi];
                [[self.volumeWindow viewerController]deleteROI:[[roi osiriXROIs]anyObject]];
            }
            if ([[roi name] hasPrefix:@"CMRSegTools: Include in Infarct"]) {
                [[self.volumeWindow ROIManager] removeROI:roi];
                [[self.volumeWindow viewerController]deleteROI:[[roi osiriXROIs]anyObject]];
            }

            if ([tool isEqualToString:@"noReference"]) {
                if ([[roi name] hasPrefix:@"CMRSegTools: Remote_stddev_"]) {
                    [[self.volumeWindow ROIManager] removeROI:roi];
                    [[self.volumeWindow viewerController]deleteROI:[[roi osiriXROIs]anyObject]];
                }
                if ([[roi name] hasPrefix:@"CMRSegTools: FWHMRegion"]) {
                    [[self.volumeWindow ROIManager] removeROI:roi];
                    [[self.volumeWindow viewerController]deleteROI:[[roi osiriXROIs]anyObject]];
                }
            }
        }
    }
    if ([tool isEqualToString:@"referenceFWHM"]) {
        OSIROI *refFWHM = [[self.volumeWindow ROIManager]firstVisibleROIWithNamePrefix:@"CMRSegTools: FWHMRegion"];
        if (refFWHM) {
            [[self.volumeWindow ROIManager] removeROI:refFWHM];
            [[self.volumeWindow viewerController]deleteROI:[[refFWHM osiriXROIs]anyObject]];
        }
    }
    if ([tool isEqualToString:@"referenceSD"]) {
        OSIROI *refSD = [[self.volumeWindow ROIManager]firstVisibleROIWithNamePrefix:@"CMRSegTools: Remote_stddev_"];
        if (refSD) {
            [[self.volumeWindow ROIManager] removeROI:refSD];
            [[self.volumeWindow viewerController]deleteROI:[[refSD osiriXROIs]anyObject]];
        }
    }
}

- (IBAction)updateStddev:(id)sender
{
    self.stddevStepper.integerValue = [sender integerValue];
    self.stddevTextField.integerValue = [sender integerValue];
    
    OSIVolumeWindow *volumeWindow = self.volumeWindow;
    
    OSIROI *remoteROI = [[volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Remote_stddev_"];
    if (remoteROI) {
        ROI* osirixROI = [[remoteROI osiriXROIs] anyObject];
        [osirixROI setName:[NSString stringWithFormat:@"CMRSegTools: Remote_stddev_%lld", (long long)[sender integerValue]]];
    }
    
    OSIROI *remoteOutsideROI = [[volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium;xSD_Segment_"];
    if (remoteOutsideROI) {
        int seg = 0;
        NSArray *epiNameComponents = [[remoteOutsideROI name] componentsSeparatedByString:@";"];
        for (NSString *component in epiNameComponents) {
            if ([component hasPrefix:@"xSD_Segment_"]) {
                seg = [[component substringFromIndex:[@"xSD_Segment_" length]] integerValue];
            }
        }
        ROI* osirixROI = [[remoteOutsideROI osiriXROIs] anyObject];
        [osirixROI setName:[NSString stringWithFormat:@"CMRSegTools: Epicardium;xSD_Segment_%d;xSD_Remote_stddev_%lld",seg ,(long long)[sender integerValue]]];
    }
}

- (IBAction)updateSegment:(id)sender
{
    self.segmentStepper.integerValue = [sender integerValue];
    self.segmentTextField.integerValue = [sender integerValue];
    
    OSIVolumeWindow *volumeWindow = self.volumeWindow;
    
    OSIROI *remoteOutsideROI = [[volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium;xSD_Segment_"];
    if (remoteOutsideROI) {
        float std = 0;
        NSArray *epiNameComponents = [[remoteOutsideROI name] componentsSeparatedByString:@";"];
        for (NSString *component in epiNameComponents) {
            if ([component hasPrefix:@"xSD_Remote_stddev_"]) {
                std = [[component substringFromIndex:[@"xSD_Remote_stddev_" length]] floatValue];
            }
        }
        ROI* osirixROI = [[remoteOutsideROI osiriXROIs] anyObject];
        [osirixROI setName:[NSString stringWithFormat:@"CMRSegTools: Epicardium;xSD_Segment_%lld;xSD_Remote_stddev_%f", (long long)[sender integerValue],std]];
    }
    
    OSIROI *regionOutsideROI = [[volumeWindow ROIManager] CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium;FWHM_Segment_"];
    if (regionOutsideROI) {
        ROI* osirixROI = [[regionOutsideROI osiriXROIs] anyObject];
        [osirixROI setName:[NSString stringWithFormat:@"CMRSegTools: Epicardium;FWHM_Segment_%lld", (long long)[sender integerValue]]];
    }
}

- (OSIVolumeWindow*)segToolsStepVolumeWindow:(CMRSegToolsStep*)step
{
    return self.volumeWindow;
}

- (void)segToolsStepDidFinish:(CMRSegToolsStep*)step
{
    [quickDrawButton.progressIndicator stopAnimation:self];
    [runBEASButton.progressIndicator stopAnimation:self];
    [popUpSegmentationProgressIndicator stopAnimation:self];
    [epicardiumButton.progressIndicator stopAnimation:self];
    [endocardiumButton.progressIndicator stopAnimation:self];
    [LVRVButton.progressIndicator stopAnimation:self];
    [includeROIButton.progressIndicator stopAnimation:self];
    [excludeROIButton.progressIndicator stopAnimation:self];
    [noReflowROIButton.progressIndicator stopAnimation:self];
    [growIncludeRegionButton.progressIndicator stopAnimation:self];
    [growNoReflowRegionButton.progressIndicator stopAnimation:self];
    [angleWiperButton.progressIndicator stopAnimation:self];
    
    [self _startStep:nil];
}

- (void)segToolsStepDidCancel:(CMRSegToolsStep*)step
{
    [quickDrawButton.progressIndicator stopAnimation:self];
    [runBEASButton.progressIndicator stopAnimation:self];
    [popUpSegmentationProgressIndicator stopAnimation:self];
    [epicardiumButton.progressIndicator stopAnimation:self];
    [endocardiumButton.progressIndicator stopAnimation:self];
    [LVRVButton.progressIndicator stopAnimation:self];
    [includeROIButton.progressIndicator stopAnimation:self];
    [excludeROIButton.progressIndicator stopAnimation:self];
    [noReflowROIButton.progressIndicator stopAnimation:self];
    [growIncludeRegionButton.progressIndicator stopAnimation:self];
    [growNoReflowRegionButton.progressIndicator stopAnimation:self];
    [angleWiperButton.progressIndicator stopAnimation:self];

    [self _startStep:nil];
}

- (void)histogramViewDidChangeCursorValues:(CMRHistogramView *)histogramView
{
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    NSInteger i;
    NSString *component;
    BOOL fixedThreshold = NO;
    
    OSIROI *outsideROI = [roiManager visibleEpicardialROI];
    if (outsideROI) {
        NSMutableArray *epiNameComponents = [NSMutableArray arrayWithArray:[[outsideROI name] componentsSeparatedByString:@";"]];
        
        for (i = 0; i < [epiNameComponents count]; i++) {
            component = [epiNameComponents objectAtIndex:i];
            if ([component hasPrefix:@"Infarct_threshold_"]) {
                component = [CMRSegTools rangeStringWithPrefix:@"Infarct_threshold_" min:histogramView.cursorValueMin max:histogramView.cursorValueMax];
                [epiNameComponents replaceObjectAtIndex:i withObject:component];
                fixedThreshold = YES;
                break;
            }
        }
        
        if (fixedThreshold == NO) {
            [epiNameComponents addObject:[CMRSegTools rangeStringWithPrefix:@"Infarct_threshold_" min:histogramView.cursorValueMin max:histogramView.cursorValueMax]];
        }
        
        NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: Epicardium"];
        for (i = 1; i < [epiNameComponents count]; i++) {
            [newName appendFormat:@";%@", [epiNameComponents objectAtIndex:i]];
        }

        ROI* osirixROI = [[outsideROI osiriXROIs] anyObject];
        [osirixROI setName:newName];
    }
}

- (IBAction)updateNumberOfSections:(id)sender
{
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    NSString *component;
    NSInteger i;
    OSIROI *LVRVROI = [roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"]; // use the name prefix because we will tag other info to this name
    BOOL draw6sections = YES;
    
    if ([[self.sectionNumberPopUpButton titleOfSelectedItem] isEqualToString:@"4"]) {
        draw6sections = NO;
    }
        
    if (LVRVROI) {
        NSArray *LVRVNameComponents = [[LVRVROI name] componentsSeparatedByString:@";"];
        NSMutableArray *newLVRVNameComponents = [NSMutableArray array];
        
        if (draw6sections == NO) {
            BOOL hasNumberOfSections = NO;
            
            for (component in LVRVNameComponents) {
                if ([component hasPrefix:@"Number_of_sections_"]) {
                    if ([component isEqualToString:@"Number_of_sections_4"]) {
                        [newLVRVNameComponents addObject:component];
                        hasNumberOfSections = YES;
                    }
                } else {
                    [newLVRVNameComponents addObject:component];
                }
            }
            if (hasNumberOfSections == NO) {
                [newLVRVNameComponents addObject:[NSString stringWithFormat:@"Number_of_sections_4"]];
            }
        } else {
            for (component in LVRVNameComponents) {
                if ([component hasPrefix:@"Number_of_sections_"] == NO) {
                    [newLVRVNameComponents addObject:component];
                }
            }
        }
        
        NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: LV/RV"];
        for (i = 1; i < [newLVRVNameComponents count]; i++) {
            [newName appendFormat:@";%@", [newLVRVNameComponents objectAtIndex:i]];
        }
        
        if ([[LVRVROI name] isEqualToString:newName] == NO) {
            ROI* osirixROI = [[LVRVROI osiriXROIs] anyObject];
            [osirixROI setName:newName];
        }
    }
}

- (IBAction)updateStatisticSelector:(id)sender
{
    [self _roisDidUpdateNotification:nil];
}

- (IBAction)userPointBEAS:(id)sender
{
    CMRSegToolsBEASPointStep *BEASPointStep = [[[CMRSegToolsBEASPointStep alloc] init] autorelease];
    BEASPointStep.histogramWindowController = self;
    [self _startStep:BEASPointStep];
    [runBEASButton.progressIndicator startAnimation:self];
}

- (IBAction)quickDraw:(id)sender
{
    CMRSegToolsQuickDrawStep *quickDrawStep = [[[CMRSegToolsQuickDrawStep alloc] init] autorelease];
    if ([[self.sectionNumberPopUpButton titleOfSelectedItem] isEqualToString:@"4"]) {
        [quickDrawStep setDraw6Sections:NO];
    } else {
        [quickDrawStep setDraw6Sections:YES];
    }
    [self _startStep:quickDrawStep];
    [quickDrawButton.progressIndicator startAnimation:self];
}

- (IBAction)drawEpicardium:(id)sender
{
    NSColor *epicardiumColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMREpicardiumColor"]];
    [self _startStep:[[[CMRSegToolsDrawROIStep alloc] initWithROIName:@"CMRSegTools: Epicardium" toolTag:11 color:epicardiumColor] autorelease]];
    [epicardiumButton.progressIndicator startAnimation:self];
}

- (IBAction)drawEndocardium:(id)sender
{
    NSColor *endocardiumColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMREndocardiumColor"]];
    [self _startStep:[[[CMRSegToolsDrawROIStep alloc] initWithROIName:@"CMRSegTools: Endocardium" toolTag:11 color:endocardiumColor] autorelease]];

    [endocardiumButton.progressIndicator startAnimation:self];
}

- (IBAction)drawLVRV:(id)sender
{
    NSColor *LVRVColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRLVRVColor"]];
    if ([[self.sectionNumberPopUpButton titleOfSelectedItem] isEqualToString:@"4"]) {
        [self _startStep:[[[CMRSegToolsDrawROIStep alloc] initWithROIName:@"CMRSegTools: LV/RV;Number_of_sections_4" toolTag:5 color:LVRVColor] autorelease]];
    } else {
        [self _startStep:[[[CMRSegToolsDrawROIStep alloc] initWithROIName:@"CMRSegTools: LV/RV" toolTag:5 color:LVRVColor] autorelease]];
    }
    [LVRVButton.progressIndicator startAnimation:self];
}



/**
 @returns a pointer to an existing ITKSegmentation3DController instance, or nil if no such instance exists
 */
- (NSWindowController*)ITKSegmentation3DController {
    for (NSWindow* window in [NSApp windows])
        if ([window.windowController isKindOfClass:NSClassFromString(@"ITKSegmentation3DController")])
            return window.windowController;
    return nil;
}

- (IBAction)growIncludeRegion:(CMRActivityButton*)sender
{
    if (sender.state) {
        NSColor *segmentedColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRMIColor"]];
        [self _startStep:[[[CMRSegToolsGrowRegionStep alloc] initWithROIName:@"CMRSegTools: Include in Infarct" color:[segmentedColor colorWithAlphaComponent:.1]] autorelease] sticky:sender];
        [growIncludeRegionButton.progressIndicator startAnimation:self];
    } else {
        NSWindowController* itksc = [self ITKSegmentation3DController];
        if (itksc)
            [itksc close];
        else [self segToolsStepDidCancel:nil];
    }
}

- (IBAction)growNoReflowRegion:(CMRActivityButton*)sender
{
    if (sender.state) {
        NSColor *noReflowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRNoReflowColor"]];
        [self _startStep:[[[CMRSegToolsGrowRegionStep alloc] initWithROIName:@"CMRSegTools: No-reflow" color:[noReflowColor colorWithAlphaComponent:.1]] autorelease] sticky:sender];
        [growNoReflowRegionButton.progressIndicator startAnimation:self];
    } else {
        NSWindowController* itksc = [self ITKSegmentation3DController];
        if (itksc)
            [itksc close];
        else [self segToolsStepDidCancel:nil];
    }
}




- (IBAction)drawIncludeROI:(CMRActivityButton*)sender
{
    if (sender.state) {
        NSColor *segmentedColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRMIColor"]];
        [self _startStep:[[[CMRSegToolsDrawROIStep alloc] initWithROIName:@"CMRSegTools: Include in Infarct" toolTag:20 color:[segmentedColor colorWithAlphaComponent:.1] mode:CMRSegToolsDrawMoreROIStepMode] autorelease] sticky:sender];
        
        [self _setBrushToolToDraw];
        [[[self.volumeWindow viewerController] window] makeKeyAndOrderFront:self];
        
        [includeROIButton.progressIndicator startAnimation:self];
    } else [self segToolsStepDidCancel:nil];
}

- (IBAction)drawExcludeROI:(CMRActivityButton*)sender
{
    if (sender.state) {
        NSColor *excludeColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRExcludeColor"]];
        [self _startStep:[[[CMRSegToolsDrawROIStep alloc] initWithROIName:@"CMRSegTools: Exclude from Infarct" toolTag:20 color:[excludeColor colorWithAlphaComponent:.3] mode:CMRSegToolsDrawMoreROIStepMode] autorelease] sticky:sender];

    //    self.clickDrawMode = CMRClickDrawModeExcludeROI;
        
        [self _setBrushToolToDraw];
        [[[self.volumeWindow viewerController] window] makeKeyAndOrderFront:self];
        
        [excludeROIButton.progressIndicator startAnimation:self];
    } else [self segToolsStepDidCancel:nil];
}

- (IBAction)drawNoReflowROI:(CMRActivityButton*)sender
{
    if (sender.state) {
        NSColor *noReflowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRNoReflowColor"]];
        [self _startStep:[[[CMRSegToolsDrawROIStep alloc] initWithROIName:@"CMRSegTools: No-reflow" toolTag:20 color:[noReflowColor colorWithAlphaComponent:.1] mode:CMRSegToolsDrawMoreROIStepMode] autorelease] sticky:sender];

        [self _setBrushToolToDraw];
        [[[self.volumeWindow viewerController] window] makeKeyAndOrderFront:self];
        
        [noReflowROIButton.progressIndicator startAnimation:self];
    } else [self segToolsStepDidCancel:nil];
}




- (IBAction)drawAngleWiper:(id)sender
{
    [self _startStep:[[[CMRSegToolsAngleWiperStep alloc] init] autorelease]];
    [angleWiperButton.progressIndicator startAnimation:self];
}

- (IBAction)setHistogramThreshold:(id)sender
{
    [popUpSegmentation selectItemAtIndex:0];
    // either turn it on or off...    
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    NSString *component;
    NSInteger i;
    OSIROI *outsideROI = [roiManager visibleEpicardialROI];

    if (outsideROI) {
        NSArray *epiNameComponents = [[outsideROI name] componentsSeparatedByString:@";"];
        NSMutableArray *newEpiNameComponents = [NSMutableArray array];
        
        if ([sender state] == NSOnState) { 
            BOOL hasThreshold = NO;
            
            for (component in epiNameComponents) {
                [newEpiNameComponents addObject:component];
                if ([component hasPrefix:@"Infarct_threshold_"]) {
                    hasThreshold = YES;
                }
            }
            if (hasThreshold == NO) {
//                float thresholdValue = (self.histogramView.domainMin + self.histogramView.domainMax) / 2.0f;
                [newEpiNameComponents addObject:[CMRSegTools rangeStringWithPrefix:@"Infarct_threshold_" min:self.histogramView.cursorValueMin max:self.histogramView.cursorValueMax]];
            }
        } else {
            for (component in epiNameComponents) {
                if ([component hasPrefix:@"Infarct_threshold_"] == NO) {
                    [newEpiNameComponents addObject:component];
                }
            }
        }
                
        NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: Epicardium"];
        for (i = 1; i < [newEpiNameComponents count]; i++) {
            [newName appendFormat:@";%@", [newEpiNameComponents objectAtIndex:i]];
        }
        
        if ([[outsideROI name] isEqualToString:newName] == NO) {
            ROI* osirixROI = [[outsideROI osiriXROIs] anyObject];
            [osirixROI setName:newName];
        }
    }
}

- (IBAction)setHistogramRangeValue:(id)sender {
    if (sender == self.histogramRangeMinField) {
        self.histogramView.cursorValueMin = self.histogramRangeMinField.floatValue;
    }
    else if (sender == self.histogramRangeMaxField) {
        self.histogramView.cursorValueMax = self.histogramRangeMaxField.floatValue;
    }
    
    [self histogramViewDidChangeCursorValues:self.histogramView];
}

- (IBAction)setNR:(id)sender
{
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];

    if ([sender state] == NSOnState) {
        NSArray *arrayROIs = [[self.volumeWindow ROIManager]ROIs];
        for (OSIROI *Roi in arrayROIs) {
            if ([[Roi name] hasPrefix:@"Hsu: No-reflow"]) {
                OSIROIMask *mask = [Roi ROIMaskForFloatVolumeData:floatVolumeData];
                OSIMaskROI *newROI = [[[OSIMaskROI alloc] initWithROIMask:mask homeFloatVolumeData:floatVolumeData name:@"Hsu: No-reflow;yes"] autorelease];
                [[self.volumeWindow ROIManager]addROI:newROI];
                [[self.volumeWindow ROIManager]removeROI:Roi];
            }
            if ([[Roi name] hasPrefix:@"hmrf: No-reflow"]) {
                NSLog(@"hmrf");
                OSIROIMask *mask = [Roi ROIMaskForFloatVolumeData:floatVolumeData];
                OSIMaskROI *newROI = [[[OSIMaskROI alloc] initWithROIMask:mask homeFloatVolumeData:floatVolumeData name:@"hmrf: No-reflow;yes"] autorelease];
                [[self.volumeWindow ROIManager]addROI:newROI];
                [[self.volumeWindow ROIManager]removeROI:Roi];
            }
        }
    }
    else
    {
        NSArray *arrayROIs = [[self.volumeWindow ROIManager]ROIs];
        for (OSIROI *Roi in arrayROIs) {
            if ([[Roi name] hasPrefix:@"Hsu: No-reflow"]) {
                OSIROIMask *mask = [Roi ROIMaskForFloatVolumeData:floatVolumeData];
                OSIMaskROI *newROI = [[[OSIMaskROI alloc] initWithROIMask:mask homeFloatVolumeData:floatVolumeData name:@"Hsu: No-reflow;no"] autorelease];
                [[self.volumeWindow ROIManager]addROI:newROI];
                [[self.volumeWindow ROIManager]removeROI:Roi];
            }
            if ([[Roi name] hasPrefix:@"hmrf: No-reflow"]) {
                NSLog(@"hmrf");
                OSIROIMask *mask = [Roi ROIMaskForFloatVolumeData:floatVolumeData];
                OSIMaskROI *newROI = [[[OSIMaskROI alloc] initWithROIMask:mask homeFloatVolumeData:floatVolumeData name:@"hmrf: No-reflow;no"] autorelease];
                [[self.volumeWindow ROIManager]addROI:newROI];
                [[self.volumeWindow ROIManager]removeROI:Roi];
            }
        }
    }
}
- (IBAction)exportData:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setTitle:@"Export CMRSegTools Data"];
    [savePanel setAllowsOtherFileTypes:NO];
    [savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"xls"]];
    [savePanel setCanCreateDirectories:YES];

    [savePanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
//            NSError *error = nil;
            NSURL *fileURL;
            fileURL = [savePanel URL];
            
            NSURL *exportTemplateURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"ExportTemplate" withExtension:@"txt"];
            NSURL *endocardialSurfaceTemplateURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"EndocardialSurfaceTemplate" withExtension:@"txt"];
            NSURL *endocardialSurfaceHeaderURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"EndocardialSurfaceHeader" withExtension:@"txt"];
            NSURL *extendedReportTemplateURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"ExtendedReportTemplate" withExtension:@"txt"];
            NSURL *sectorStatsTemplateURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"SectorStatsTemplate" withExtension:@"txt"];
            NSURL *sectorStatsHeaderURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"SectorStatsHeader" withExtension:@"txt"];
            NSMutableString *templateString = [NSMutableString stringWithContentsOfURL:exportTemplateURL encoding:NSMacOSRomanStringEncoding error:NULL];
            
            NSArray *sharedStringsKeys = [self _sharedStringsKeys];
            NSDictionary *sharedStringsReplacementValues = [self _sharedStringsReplacementValues];
            for (NSString *sharedStringsKey in sharedStringsKeys) {
                NSString *value = [self _stringForISOLatinEncoding:[sharedStringsReplacementValues objectForKey:sharedStringsKey]];
                if (value == nil) {
                    value = @"n/a";
                }
                
                [templateString replaceOccurrencesOfString:sharedStringsKey withString:value options:NSLiteralSearch range:NSMakeRange(0, [templateString length])];
            }
            
            NSArray *sheet1Keys = [self _sheet1Keys];
            NSDictionary *sheet1Values = [self _sheet1ReplacementValues];
            for (NSNumber *sheet1Key in sheet1Keys) {
                NSString *value = nil;
                if ([sheet1Values objectForKey:sheet1Key]) {
                    value = [NSString stringWithFormat:@"%f", [[sheet1Values objectForKey:sheet1Key] doubleValue]];
                }
                if (value == nil) {
                    value = @"n/a";
                }
                
                [templateString replaceOccurrencesOfString:[sheet1Key stringValue] withString:value options:NSLiteralSearch range:NSMakeRange(0, [templateString length])];
            }
            
            NSInteger i;
            NSArray *extendedReportKeys = [self _extendedReportKeys];
            for (i = 0; i < [[[[self.volumeWindow viewerController] imageView] dcmPixList] count]; i++) {
                NSDictionary *extendedReportValues = [self _extendedReportReplacementValuesForMovieIndex:0 pixIndex:i];
                NSMutableString *extendedReportTemplateString = [NSMutableString stringWithContentsOfURL:extendedReportTemplateURL encoding:NSMacOSRomanStringEncoding error:NULL];
                
                for (NSNumber *extendedReportKey in extendedReportKeys) {
                    NSString *value = nil;
                    if ([extendedReportValues objectForKey:extendedReportKey]) {
                        value = [NSString stringWithFormat:@"%f", [[extendedReportValues objectForKey:extendedReportKey] doubleValue]];
                    }
                    if (value == nil) {
                        value = @"0";
                    }
                    
                    [extendedReportTemplateString replaceOccurrencesOfString:[extendedReportKey stringValue] withString:value options:NSLiteralSearch range:NSMakeRange(0, [extendedReportTemplateString length])];
                }
                
                [templateString appendString:extendedReportTemplateString];
            }
            
            NSArray *ESAKeys = [self _ESAKeys];
            NSDictionary *ESAValues = [self _ESAReplacementValues];
            NSMutableString *endocardialSurfaceHeaderString = [NSMutableString stringWithContentsOfURL:endocardialSurfaceHeaderURL encoding:NSMacOSRomanStringEncoding error:NULL];
            
            for (NSNumber *ELAKey in ESAKeys) {
                NSString *value = nil;
                if ([ESAValues objectForKey:ELAKey]) {
                    value = [NSString stringWithFormat:@"%f", [[ESAValues objectForKey:ELAKey] doubleValue]];
                }
                if (value == nil) {
                    value = @"0";
                }
                
                [endocardialSurfaceHeaderString replaceOccurrencesOfString:[ELAKey stringValue] withString:value options:NSLiteralSearch range:NSMakeRange(0, [endocardialSurfaceHeaderString length])];
            }
            [templateString appendString:endocardialSurfaceHeaderString];
            
            NSArray *ESLKeys = [self _ESLKeys];
            NSInteger sector;
            for (i = 0; i < [[[[self.volumeWindow viewerController] imageView] dcmPixList] count]; i++) {
                for (sector = 1; sector <= 6; sector++) {
                    NSDictionary *ESLValues = [self _ESLReplacementValuesForSector:sector movieIndex:0 pixIndex:i];
                    NSMutableString *ESLTemplateString = [NSMutableString stringWithContentsOfURL:endocardialSurfaceTemplateURL encoding:NSMacOSRomanStringEncoding error:NULL];
                    
                    for (NSNumber *ESLKey in ESLKeys) {
                        NSString *value = nil;
                        if ([ESLValues objectForKey:ESLKey]) {
                            value = [NSString stringWithFormat:@"%f", [[ESLValues objectForKey:ESLKey] doubleValue]];
                        }
                        if (value == nil) {
                            value = @"0";
                        }
                        
                        [ESLTemplateString replaceOccurrencesOfString:[ESLKey stringValue] withString:value options:NSLiteralSearch range:NSMakeRange(0, [ESLTemplateString length])];
                    }
                    
                    [templateString appendString:ESLTemplateString];
                }
            }
            

            NSMutableString *sectorStatsHeader = [NSMutableString stringWithContentsOfURL:sectorStatsHeaderURL encoding:NSMacOSRomanStringEncoding error:NULL];
            [templateString appendString:sectorStatsHeader];
            
            NSArray *sectorStatsKeys = [self _sectorStatsKeys];
            for (i = 0; i < [[[[self.volumeWindow viewerController] imageView] dcmPixList] count]; i++) {
                for (sector = 1; sector <= 6; sector++) {
                    NSDictionary *sectorStatsValues = [self _sectorStatsReplacementValuesForSector:sector movieIndex:0 pixIndex:i];
                    NSMutableString *sectorStatsTemplateString = [NSMutableString stringWithContentsOfURL:sectorStatsTemplateURL encoding:NSMacOSRomanStringEncoding error:NULL];

                    for (NSNumber *sectorStatsKey in sectorStatsKeys) {
                        NSString *value = nil;
                        if ([sectorStatsValues objectForKey:sectorStatsKey]) {
                            value = [NSString stringWithFormat:@"%f", [[sectorStatsValues objectForKey:sectorStatsKey] doubleValue]];
                        }
                        if (value == nil) {
                            value = @"0";
                        }
                        
                        [sectorStatsTemplateString replaceOccurrencesOfString:[sectorStatsKey stringValue] withString:value options:NSLiteralSearch range:NSMakeRange(0, [sectorStatsTemplateString length])];
                    }
                    
                    [templateString appendString:sectorStatsTemplateString];
                }
            }

            
            [templateString writeToURL:fileURL atomically:YES encoding:NSISOLatin1StringEncoding error:NULL];
        }
    }];
}

- (void)_setBrushToolToDraw
{
	NSArray *winList = [NSApp windows];
    PaletteController *paletteController = nil;
	
	for( id loopItem in winList) {
		if( [[[loopItem windowController] windowNibName] isEqualToString:@"PaletteBrush"]) {
			paletteController = [loopItem windowController];
		}
	}
	
    if (paletteController) {
        [[paletteController modeControl] setSelectedSegment:0];
        [[[self.volumeWindow viewerController] imageView] setEraserFlag:0];
    }
}

- (NSArray *)_sharedStringsKeys
{
    return @[@"___analysis_date____",
             @"___patient_name____",
             @"___aquisistion_date___",
             @"___series_number___",
             @"___series_description___",
             @"___sequence_name___"];
}

- (NSArray *)_sheet1Keys
{
    NSMutableArray *keys = [NSMutableArray arrayWithArray:@[[NSNumber numberWithInteger:TotalLVMass],
                            [NSNumber numberWithInteger:TotalMIMass],
                            [NSNumber numberWithInteger:TotalNonMIMass],
                            [NSNumber numberWithInteger:TotalNRMass],
                            [NSNumber numberWithInteger:TotalMIPercent],
                            [NSNumber numberWithInteger:TotalNonMIPercent],
                            [NSNumber numberWithInteger:TotalNRPercent],
                            [NSNumber numberWithInteger:TotalLVVol],
                            [NSNumber numberWithInteger:TotalMIVol],
                            [NSNumber numberWithInteger:TotalNonMIVol],
                            [NSNumber numberWithInteger:TotalNRVol],
                            [NSNumber numberWithInteger:SliceNumberValueTag]]];
    
    NSUInteger i;
    NSUInteger j;
    
    for (i = MyocardiumValueTagMask; i <= NRValueTagMask; i+=10000) {
        for (j = AreaValueTagMask; j <= MinValueTagMask; j++) {
            [keys addObject:[NSNumber numberWithInteger:i + j]];
        }
    }
    
    return keys;
}

- (NSArray *)_extendedReportKeys
{
    NSMutableArray *keys = [NSMutableArray arrayWithObject:[NSNumber numberWithInteger:SliceNumberValueTag]];
    NSUInteger i;
    NSUInteger j;

    for (i = Segment1ValueTagMask; i <= Segment6ValueTagMask; i+=10000) {
        for (j = MIMassValueTagMask; j <= NRAreaValueTagMask; j++) {
            [keys addObject:[NSNumber numberWithInteger:i + j]];
        }
    }
    
    return keys;
}

- (NSArray *)_sectorStatsKeys
{
    NSMutableArray *keys = [NSMutableArray arrayWithArray:@[[NSNumber numberWithInteger:SliceNumberValueTag], [NSNumber numberWithInteger:SectorNumberValueTag]]];
    NSUInteger i;
    NSUInteger j;
        
    for (i = MyocardiumValueTagMask; i <= NRValueTagMask; i+=10000) {
        for (j = AreaValueTagMask; j <= MinValueTagMask; j++) {
            [keys addObject:[NSNumber numberWithInteger:i + j]];
        }
    }
    
    return keys;
}

- (NSArray *)_ESAKeys
{
    return @[[NSNumber numberWithInteger:ESAPercentTag], [NSNumber numberWithInteger:ESAAreaTag]];
}

- (NSDictionary *)_ESAReplacementValues
{
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    NSMutableDictionary *replacementValues = [NSMutableDictionary dictionary];

    
    OSIROI *lengthEndocardiumROI = [[self.volumeWindow ROIManager] CMRFirstVisibleROIWithName:@"clipped endocardium"];
    OSIROI *lengthWholeEndocardiumROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
    N3BezierPath *path = [lengthEndocardiumROI performSelector:@selector(path)]; // perform selector because I forgot to hook up the accessor for bezierPath
    N3BezierPath *wholePath = [lengthWholeEndocardiumROI bezierPath];
    
    float pathLength = [path length];
    float wholePathLength = [wholePath length];
    
    NSInteger movieIndex = [[self.volumeWindow viewerController] curMovieIndex];
    NSUInteger i;
    float totalEndocardialLength = 0;
    float totalInfactLength = 0;
    
    for (i = 0; i < [[[[self.volumeWindow viewerController] imageView] dcmPixList] count]; i++) {
        lengthEndocardiumROI = [[self.volumeWindow ROIManager] CMRFirstROIWithNamePrefix:@"clipped endocardium" movieIndex:movieIndex pixIndex:i];
        lengthWholeEndocardiumROI = [[self.volumeWindow ROIManager] endocardialROIAtMovieIndex:movieIndex pixIndex:i];
        path = [lengthEndocardiumROI performSelector:@selector(path)]; // perform selector because I forgot to hook up the accessor for bezierPath
        wholePath = [lengthWholeEndocardiumROI bezierPath];
        pathLength = [path length];
        wholePathLength = [wholePath length];
        
        if (wholePathLength) {
            totalEndocardialLength += wholePathLength;
            totalInfactLength += pathLength;
        }
    }
    
    if (totalEndocardialLength) {
        [replacementValues setObject:[NSString stringWithFormat:@"%f", (totalInfactLength/totalEndocardialLength) * 100.0] forKey:[NSNumber numberWithInteger:ESAPercentTag]];
    }
    
    NSArray *allROIs = [[self.volumeWindow ROIManager] ROIsWithName:@"clipped endocardium"];
    double totalLength = 0;
    for (OSIROI* roi in allROIs) {
        path = [roi performSelector:@selector(path)]; // perform selector because I forgot to hook up the accessor for bezierPath
        totalLength += [path length] * 0.1;
    }
    
    [replacementValues setObject:[NSString stringWithFormat:@"%f", totalLength * [floatVolumeData pixelSpacingZ] * 0.1] forKey:[NSNumber numberWithInteger:ESAAreaTag]];
    
    return replacementValues;
}

- (NSArray *)_ESLKeys
{
    return @[[NSNumber numberWithInteger:SliceNumberValueTag],
             [NSNumber numberWithInteger:SectorNumberValueTag],
             [NSNumber numberWithInteger:ESLTag+AreaValueTagMask],
             [NSNumber numberWithInteger:ESLTag+MeanValueTagMask],
             [NSNumber numberWithInteger:ESLTag+MaxValueTagMask],
             [NSNumber numberWithInteger:ESLTag+MinValueTagMask]];
}

- (NSDictionary *)_ESLReplacementValuesForSector:(NSInteger)sector movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex
{
    NSMutableDictionary *replacementValues = [NSMutableDictionary dictionary];
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    
    OSIROI *lengthEndocardiumROI = [[self.volumeWindow ROIManager] CMRFirstROIWithName:@"clipped endocardium" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *lengthWholeEndocardiumROI = [[self.volumeWindow ROIManager] endocardialROIAtMovieIndex:movieIndex pixIndex:pixIndex];
    N3BezierPath *path = [lengthEndocardiumROI performSelector:@selector(path)]; // perform selector because I forgot to hook up the accessor for bezierPath
    N3BezierPath *wholePath = [lengthWholeEndocardiumROI bezierPath];
    
    [replacementValues setObject:[NSNumber numberWithInteger:pixIndex + 1] forKey:[NSNumber numberWithInteger:SliceNumberValueTag]];
    [replacementValues setObject:[NSNumber numberWithInteger:sector] forKey:[NSNumber numberWithInteger:SectorNumberValueTag]];

    float pathLength = [path length];
    float wholePathLength = [wholePath length];
    if (wholePathLength) {
        [replacementValues setObject:[NSString stringWithFormat:@"%f", (pathLength/wholePathLength) * 100.0] forKey:[NSNumber numberWithInteger:ESLTag+AreaValueTagMask]];
    }
    
    OSIROI *infactStartAngleROI = [[self.volumeWindow ROIManager] CMRFirstROIWithNamePrefix:@"CMRSegTools: Infarct Start Angle" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *LVRVROI = [[self.volumeWindow ROIManager] CMRFirstROIWithNamePrefix:@"CMRSegTools: LV/RV" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *infactEndAngleROI = [[self.volumeWindow ROIManager] CMRFirstROIWithNamePrefix:@"CMRSegTools: Infarct End Angle" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *myocardiumROI = [[self.volumeWindow ROIManager] CMRFirstROIWithName:@"myocardium" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *nonWedgeClippedSegementedROI = [[self.volumeWindow ROIManager] CMRFirstROIWithName:@"nonWedgeClippedSegmented" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *sectorROI = [[self.volumeWindow ROIManager] CMRFirstROIWithName:[NSString stringWithFormat:@"myocardium segment %ld", (long)sector] movieIndex:movieIndex pixIndex:pixIndex];

    OSIROIMask *myocardiumMask = [myocardiumROI ROIMaskForFloatVolumeData:[myocardiumROI homeFloatVolumeData]];
    OSIROIMask *nonWedgeClippedSegementedMask = [nonWedgeClippedSegementedROI ROIMaskForFloatVolumeData:[nonWedgeClippedSegementedROI homeFloatVolumeData]];
    
    NSUInteger sectorCount = 0;
    N3Vector sectorLineStart = N3VectorZero;
    N3Vector sectorLineEnd = N3VectorZero;
    if (LVRVROI && [[LVRVROI bezierPath] elementCount] == 2) {
        sectorCount = 6;
        NSArray *LVRVNameComponents = [[LVRVROI name] componentsSeparatedByString:@";"];
        for (NSString *component in LVRVNameComponents) {
            if ([component hasPrefix:@"Number_of_sections_"]) {
                sectorCount = [[component substringFromIndex:[@"Number_of_sections_" length]] integerValue];
            }
        }
        [[LVRVROI bezierPath] elementAtIndex:0 control1:NULL control2:NULL endpoint:&sectorLineStart];
        [[LVRVROI bezierPath] elementAtIndex:1 control1:NULL control2:NULL endpoint:&sectorLineEnd];
    }
    
    if (infactStartAngleROI && infactEndAngleROI && lengthEndocardiumROI && myocardiumROI && nonWedgeClippedSegementedROI &&
        myocardiumMask && sectorROI && nonWedgeClippedSegementedMask) {
        
        N3Vector normalVector = N3VectorApplyTransformToDirectionalVector(N3VectorMake(0, 0, 1), N3AffineTransformInvert(floatVolumeData.volumeTransform));
        N3Vector startVector0 = N3VectorZero;
        N3Vector startVector1 = N3VectorZero;
        N3Vector endVector0 = N3VectorZero;
        N3Vector endVector1 = N3VectorZero;
        
        [[infactStartAngleROI bezierPath] elementAtIndex:0 control1:NULL control2:NULL endpoint:&startVector0];
        [[infactStartAngleROI bezierPath] elementAtIndex:1 control1:NULL control2:NULL endpoint:&startVector1];
        
        [[infactEndAngleROI bezierPath] elementAtIndex:0 control1:NULL control2:NULL endpoint:&endVector0];
        [[infactEndAngleROI bezierPath] elementAtIndex:1 control1:NULL control2:NULL endpoint:&endVector1];
        
        // find out if we are using the wide angle
        BOOL useWideAngle = NO;
        if (N3VectorDotProduct(N3VectorCrossProduct(N3VectorSubtract(startVector1, startVector0), N3VectorSubtract(endVector1, endVector0)), normalVector) > 0) {
            useWideAngle = YES;
        } else {
            useWideAngle = NO;
        }
        
        CGFloat minTransmuralityValue;
        CGFloat maxTransmuralityValue;
        CGFloat meanTransmuralityValue;
        
        [[self class] _infarctTransmuralityForMyocardiumMask:myocardiumMask infarctMask:nonWedgeClippedSegementedMask
                                              firstLineStart:startVector0 firstLineEnd:startVector1
                                             secondLineStart:endVector0 secondLineEnd:endVector1
                                                useWideAngle:useWideAngle stepAngle:3.6*(M_PI/180.0)
                                             sectorLineStart:sectorLineStart sectorLineEnd:sectorLineEnd sectorCount:sectorCount sector:(NSInteger)sector
                                             volumeTransform:floatVolumeData.volumeTransform
                                            minTransmurality:&minTransmuralityValue maxTransmurality:&maxTransmuralityValue meanTransmurality:&meanTransmuralityValue];
        
        [replacementValues setObject:[NSString stringWithFormat:@"%f", meanTransmuralityValue * 100.0] forKey:[NSNumber numberWithInteger:ESLTag+MeanValueTagMask]];
        [replacementValues setObject:[NSString stringWithFormat:@"%f", maxTransmuralityValue * 100.0] forKey:[NSNumber numberWithInteger:ESLTag+MaxValueTagMask]];
        [replacementValues setObject:[NSString stringWithFormat:@"%f", minTransmuralityValue * 100.0] forKey:[NSNumber numberWithInteger:ESLTag+MinValueTagMask]];
    }
    
    return replacementValues;
}

- (NSDictionary *)_sectorStatsReplacementValuesForSector:(NSUInteger)sector movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex
{
    NSMutableDictionary *replacementValues = [NSMutableDictionary dictionary];
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    NSUInteger i;

    [replacementValues setObject:[NSNumber numberWithInteger:pixIndex + 1] forKey:[NSNumber numberWithInteger:SliceNumberValueTag]];
    [replacementValues setObject:[NSNumber numberWithInteger:sector] forKey:[NSNumber numberWithInteger:SectorNumberValueTag]];

    
    OSIROI *myocardiumROI = [roiManager CMRFirstROIWithName:@"myocardium" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *segmented = [roiManager CMRFirstROIWithName:@"segmented" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *noReflow = [roiManager CMRFirstROIWithName:@"no-reflow" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *sectorROI = [roiManager CMRFirstROIWithName:[NSString stringWithFormat:@"myocardium segment %ld", (long)sector] movieIndex:movieIndex pixIndex:pixIndex];

    if (myocardiumROI && sectorROI) {
        OSIFloatVolumeData *floatVolumeData = [myocardiumROI homeFloatVolumeData];
        OSIROIMask *sectorMask = [sectorROI ROIMaskForFloatVolumeData:floatVolumeData];
        OSIROIMask *myocardiumMask = [myocardiumROI ROIMaskForFloatVolumeData:floatVolumeData];
        
        OSIROIMask *segmentedMask = [[[OSIROIMask alloc] init] autorelease];
        if (segmented) {
            segmentedMask = [segmented ROIMaskForFloatVolumeData:floatVolumeData];
        }
        
        OSIROIMask *noReflowMask = [[[OSIROIMask alloc] init] autorelease];
        if (noReflow) {
            noReflowMask = [noReflow ROIMaskForFloatVolumeData:floatVolumeData];
        }
        
        OSIROIMask *healthyMask = [myocardiumMask ROIMaskBySubtractingMask:[segmentedMask ROIMaskByUnioningWithMask:noReflowMask]];
        
        for (i = MyocardiumValueTagMask; i <= NRValueTagMask; i+=10000) {
            OSIROIMask *mask;
            switch (i) {
                case MyocardiumValueTagMask:
                    mask = myocardiumMask;
                    break;
                case MIValueTagMask:
                    mask = segmentedMask;
                    break;
                case NonMIValueTagMask:
                    mask = healthyMask;
                    break;
                case NRValueTagMask:
                    mask = noReflowMask;
                    break;
            }
            
            OSIROIMask *valuesMask = [mask ROIMaskByIntersectingWithMask:sectorMask];
            
            if ([valuesMask maskRunCount]) {
                OSIROIFloatPixelData *pixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:[mask ROIMaskByIntersectingWithMask:sectorMask] floatVolumeData:[myocardiumROI homeFloatVolumeData]] autorelease];
                
                [replacementValues setObject:[NSNumber numberWithDouble:[self _maskArea:valuesMask floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:AreaValueTagMask+i]];
                [replacementValues setObject:[NSNumber numberWithDouble:[pixelData intensityMean]] forKey:[NSNumber numberWithInteger:MeanValueTagMask+i]];
                [replacementValues setObject:[NSNumber numberWithDouble:[pixelData intensityStandardDeviation]] forKey:[NSNumber numberWithInteger:STDDevValueTagMask+i]];
                [replacementValues setObject:[NSNumber numberWithDouble:[pixelData intensityInterQuartileRange]] forKey:[NSNumber numberWithInteger:IQRValueTagMask+i]];
                [replacementValues setObject:[NSNumber numberWithDouble:[pixelData intensityMedian]] forKey:[NSNumber numberWithInteger:MedianValueTagMask+i]];
                [replacementValues setObject:[NSNumber numberWithDouble:[pixelData intensityMax]] forKey:[NSNumber numberWithInteger:MaxValueTagMask+i]];
                [replacementValues setObject:[NSNumber numberWithDouble:[pixelData intensityMin]] forKey:[NSNumber numberWithInteger:MinValueTagMask+i]];
            }
        }
    }
    
    return replacementValues;
}

- (NSDictionary *)_sharedStringsReplacementValues;
{
    NSMutableDictionary *replacementValues = [NSMutableDictionary dictionary];
    
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
    [dateFormatter setDateFormat:@"yyyyMMdd"];
    
    [replacementValues setObject:[dateFormatter stringFromDate:[NSDate date]] forKey:@"___analysis_date____"];
    
    id obj;
    
    if ((obj = [self _stringValueFromDicomGroup:0x0010 element:0x0010]))
        [replacementValues setObject:obj forKey:@"___patient_name____"];
    
    if ((obj = [self _stringValueFromDicomGroup:0x0008 element:0x0022]))
        [replacementValues setObject:obj forKey:@"___aquisistion_date___"];
    
    if ((obj = [self _stringValueFromDicomGroup:0x0020 element:0x0011]))
        [replacementValues setObject:obj forKey:@"___series_number___"];
    
    if ((obj = [self _stringValueFromDicomGroup:0x0008 element:0x103e]))
        [replacementValues setObject:obj forKey:@"___series_description___"];
    
    if ((obj = [self _stringValueFromDicomGroup:0x0018 element:0x0024]))
        [replacementValues setObject:obj forKey:@"___sequence_name___"];
    
    return replacementValues;
}


- (NSDictionary *)_extendedReportReplacementValuesForMovieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex
{
    NSUInteger i;
    NSMutableDictionary *replacementValues = [NSMutableDictionary dictionary];
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];

    OSIROI *myocardiumROI = [roiManager CMRFirstROIWithName:@"myocardium" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *segmented = [roiManager CMRFirstROIWithName:@"segmented" movieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *noReflow = [roiManager CMRFirstROIWithName:@"no-reflow" movieIndex:movieIndex pixIndex:pixIndex];
        
    if (myocardiumROI) {
        OSIFloatVolumeData *floatVolumeData = [myocardiumROI homeFloatVolumeData];
        OSIROIMask *myocardiumMask = [myocardiumROI ROIMaskForFloatVolumeData:floatVolumeData];

        
        OSIROIMask *segmentedMask = [[[OSIROIMask alloc] init] autorelease];
        if (segmented) {
            segmentedMask = [segmented ROIMaskForFloatVolumeData:floatVolumeData];
        }
        
        OSIROIMask *noReflowMask = [[[OSIROIMask alloc] init] autorelease];
        if (noReflow) {
            noReflowMask = [noReflow ROIMaskForFloatVolumeData:floatVolumeData];
        }
        
        OSIROIMask *healthyMask = [myocardiumMask ROIMaskBySubtractingMask:[segmentedMask ROIMaskByUnioningWithMask:noReflowMask]];
                
        NSMutableArray *segmentMasks = [NSMutableArray array];
        NSMutableArray *segmentValueTagMasks = [NSMutableArray array];
        
        OSIROI *segment1ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 1" movieIndex:movieIndex pixIndex:pixIndex];
        if (segment1ROI) {
            [segmentMasks addObject:[segment1ROI ROIMaskForFloatVolumeData:floatVolumeData]];
        }
        [segmentValueTagMasks addObject:[NSNumber numberWithInteger:Segment1ValueTagMask]];
        OSIROI *segment2ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 2" movieIndex:movieIndex pixIndex:pixIndex];
        if (segment2ROI) {
            [segmentMasks addObject:[segment2ROI ROIMaskForFloatVolumeData:floatVolumeData]];
        }
        [segmentValueTagMasks addObject:[NSNumber numberWithInteger:Segment2ValueTagMask]];
        OSIROI *segment3ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 3" movieIndex:movieIndex pixIndex:pixIndex];
        if (segment3ROI) {
            [segmentMasks addObject:[segment3ROI ROIMaskForFloatVolumeData:floatVolumeData]];
        }
        [segmentValueTagMasks addObject:[NSNumber numberWithInteger:Segment3ValueTagMask]];
        OSIROI *segment4ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 4" movieIndex:movieIndex pixIndex:pixIndex];
        if (segment4ROI) {
            [segmentMasks addObject:[segment4ROI ROIMaskForFloatVolumeData:floatVolumeData]];
        }
        [segmentValueTagMasks addObject:[NSNumber numberWithInteger:Segment4ValueTagMask]];
        OSIROI *segment5ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 5" movieIndex:movieIndex pixIndex:pixIndex];
        if (segment5ROI) {
            [segmentMasks addObject:[segment5ROI ROIMaskForFloatVolumeData:floatVolumeData]];
        }
        [segmentValueTagMasks addObject:[NSNumber numberWithInteger:Segment5ValueTagMask]];
        OSIROI *segment6ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 6" movieIndex:movieIndex pixIndex:pixIndex];
        if (segment6ROI) {
            [segmentMasks addObject:[segment6ROI ROIMaskForFloatVolumeData:floatVolumeData]];
        }
        [segmentValueTagMasks addObject:[NSNumber numberWithInteger:Segment6ValueTagMask]];
        
        for (i = 0; i < [segmentMasks count]; i++) {
            OSIROIMask *segmentMask = [segmentMasks objectAtIndex:i];
            NSUInteger segmentValueTagMask = [[segmentValueTagMasks objectAtIndex:i] integerValue];
            
            [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:[myocardiumMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:LVVolValueTagMask + segmentValueTagMask]];
            
            if ([segmentedMask maskRunCount]) {
                [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:[segmentedMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData] * 1.05] forKey:[NSNumber numberWithInteger:MIMassValueTagMask + segmentValueTagMask]];
                [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:[healthyMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData] * 1.05] forKey:[NSNumber numberWithInteger:NonMIMassValueTagMask + segmentValueTagMask]];
                [replacementValues setObject:[NSNumber numberWithDouble:([self _maskVolume:[segmentedMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]/[self _maskVolume:[myocardiumMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData])*100.0] forKey:[NSNumber numberWithInteger:MIPercentValueTagMask + segmentValueTagMask]];
                [replacementValues setObject:[NSNumber numberWithDouble:((1.0-[self _maskVolume:[segmentedMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]/[self _maskVolume:[myocardiumMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]))*100.0] forKey:[NSNumber numberWithInteger:NonMIPercentValueTagMask + segmentValueTagMask]];
                [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:[segmentedMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:MIVolValueTagMask + segmentValueTagMask]];
                [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:[healthyMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:NonMIVolValueTagMask + segmentValueTagMask]];
                [replacementValues setObject:[NSNumber numberWithDouble:[self _maskArea:[segmentedMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:MIAreaValueTagMask + segmentValueTagMask]];
                [replacementValues setObject:[NSNumber numberWithDouble:[self _maskArea:[healthyMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:NonMIAreaValueTagMask + segmentValueTagMask]];
            }
            
            if ([noReflowMask maskRunCount]) {
                [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:[noReflowMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData] * 1.05] forKey:[NSNumber numberWithInteger:NRMassValueTagMask + segmentValueTagMask]];
                [replacementValues setObject:[NSNumber numberWithDouble:([self _maskVolume:[noReflowMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]/[self _maskVolume:[myocardiumMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData])*100.0] forKey:[NSNumber numberWithInteger:NRPercentValueTagMask + segmentValueTagMask]];
                [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:[noReflowMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:NRVolValueTagMask + segmentValueTagMask]];
                [replacementValues setObject:[NSNumber numberWithDouble:[self _maskArea:[noReflowMask ROIMaskByIntersectingWithMask:segmentMask] floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:NRAreaValueTagMask + segmentValueTagMask]];
            }
        }
    }
    
    [replacementValues setObject:[NSNumber numberWithInteger:pixIndex + 1] forKey:[NSNumber numberWithInteger:SliceNumberValueTag]];
    
    return replacementValues;
}


- (NSDictionary *)_sheet1ReplacementValues
{
    NSUInteger i;
    NSMutableDictionary *replacementValues = [NSMutableDictionary dictionary];
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];

    NSArray *myocardiumROIs = [roiManager ROIsWithName:@"myocardium"];
    NSArray *segmentedROIs = [roiManager ROIsWithName:@"segmented"];
    NSArray *noReflowRois = [roiManager ROIsWithName:@"no-reflow"];

    OSIROIMask *myocardium3DMask = [OSIROIMask ROIMask];
    for (OSIROI *roi in myocardiumROIs) {
        myocardium3DMask = [myocardium3DMask ROIMaskByUnioningWithMask:[roi ROIMaskForFloatVolumeData:floatVolumeData]];
    }
    
    OSIROIMask *segmented3DMask = [OSIROIMask ROIMask];
    for (OSIROI *roi in segmentedROIs) {
        segmented3DMask = [segmented3DMask ROIMaskByUnioningWithMask:[roi ROIMaskForFloatVolumeData:floatVolumeData]];
    }
    
    OSIROIMask *noReflow3DMask = [OSIROIMask ROIMask];
    for (OSIROI *roi in noReflowRois) {
        noReflow3DMask = [noReflow3DMask ROIMaskByUnioningWithMask:[roi ROIMaskForFloatVolumeData:floatVolumeData]];
    }
    
    OSIROIMask *nonMI3DMask = [myocardium3DMask ROIMaskBySubtractingMask:[segmented3DMask ROIMaskByUnioningWithMask:noReflow3DMask]];
    
    double myocardiumCount = (double)[myocardium3DMask maskIndexCount];
    double MICount = (double)[segmented3DMask maskIndexCount];
    double noReflowCount = (double)[noReflow3DMask maskIndexCount];

    if (myocardiumCount > 0) {
        [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:myocardium3DMask floatVolumeData:floatVolumeData] * 1.05] forKey:[NSNumber numberWithInteger:TotalLVMass]];
        [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:myocardium3DMask floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:TotalLVVol]];
    }

    if (MICount > 0) {
        [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:segmented3DMask floatVolumeData:floatVolumeData] * 1.05] forKey:[NSNumber numberWithInteger:TotalMIMass]];
        [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:nonMI3DMask floatVolumeData:floatVolumeData] * 1.05] forKey:[NSNumber numberWithInteger:TotalNonMIMass]];
        [replacementValues setObject:[NSNumber numberWithDouble:([self _maskVolume:segmented3DMask floatVolumeData:floatVolumeData]/[self _maskVolume:myocardium3DMask floatVolumeData:floatVolumeData])*100.0] forKey:[NSNumber numberWithInteger:TotalMIPercent]];
        [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:segmented3DMask floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:TotalMIVol]];
        [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:nonMI3DMask floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:TotalNonMIVol]];
        [replacementValues setObject:[NSNumber numberWithDouble:((1.0-[self _maskVolume:segmented3DMask floatVolumeData:floatVolumeData]/[self _maskVolume:myocardium3DMask floatVolumeData:floatVolumeData]))*100.0] forKey:[NSNumber numberWithInteger:TotalNonMIPercent]];

    }
    
    if (noReflowCount > 0) {
        [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:noReflow3DMask floatVolumeData:floatVolumeData] * 1.05] forKey:[NSNumber numberWithInteger:TotalNRMass]];
        [replacementValues setObject:[NSNumber numberWithDouble:[self _maskVolume:noReflow3DMask floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:TotalNRVol]];
        [replacementValues setObject:[NSNumber numberWithDouble:([self _maskVolume:noReflow3DMask floatVolumeData:floatVolumeData]/[self _maskVolume:myocardium3DMask floatVolumeData:floatVolumeData])*100.0] forKey:[NSNumber numberWithInteger:TotalNRPercent]];
    }

    NSMutableArray *roiMasks = [NSMutableArray array];
    NSMutableArray *roiValueTagMasks = [NSMutableArray array];
    
    [roiMasks addObject:myocardium3DMask];
    [roiValueTagMasks addObject:[NSNumber numberWithInteger:MyocardiumValueTagMask]];
    if ([segmented3DMask maskRunCount]) {
        [roiMasks addObject:segmented3DMask];
        [roiValueTagMasks addObject:[NSNumber numberWithInteger:MIValueTagMask]];
        
        if ([nonMI3DMask maskRunCount]) {
            [roiMasks addObject:nonMI3DMask];
            [roiValueTagMasks addObject:[NSNumber numberWithInteger:NonMIValueTagMask]];
        }
    }
    if ([noReflow3DMask maskRunCount]) {
        [roiMasks addObject:noReflow3DMask];
        [roiValueTagMasks addObject:[NSNumber numberWithInteger:NRValueTagMask]];
    }
    
    for (i = 0; i < [roiMasks count]; i++) {
        [replacementValues setObject:[NSNumber numberWithFloat:[self _maskArea:[roiMasks objectAtIndex:i] floatVolumeData:floatVolumeData]] forKey:[NSNumber numberWithInteger:[[roiValueTagMasks objectAtIndex:i] integerValue] + AreaValueTagMask]];
        
        OSIROIFloatPixelData *pixelData = [[OSIROIFloatPixelData alloc] initWithROIMask:[roiMasks objectAtIndex:i] floatVolumeData:floatVolumeData];
        [replacementValues setObject:[NSNumber numberWithFloat:[pixelData intensityMean]] forKey:[NSNumber numberWithInteger:[[roiValueTagMasks objectAtIndex:i] integerValue] + MeanValueTagMask]];
        [replacementValues setObject:[NSNumber numberWithFloat:[pixelData intensityMax]] forKey:[NSNumber numberWithInteger:[[roiValueTagMasks objectAtIndex:i] integerValue] + MaxValueTagMask]];
        [replacementValues setObject:[NSNumber numberWithFloat:[pixelData intensityMin]] forKey:[NSNumber numberWithInteger:[[roiValueTagMasks objectAtIndex:i] integerValue] + MinValueTagMask]];
        [replacementValues setObject:[NSNumber numberWithFloat:[pixelData intensityStandardDeviation]] forKey:[NSNumber numberWithInteger:[[roiValueTagMasks objectAtIndex:i] integerValue] + STDDevValueTagMask]];
        [replacementValues setObject:[NSNumber numberWithFloat:[pixelData intensityInterQuartileRange]] forKey:[NSNumber numberWithInteger:[[roiValueTagMasks objectAtIndex:i] integerValue] + IQRValueTagMask]];
        [replacementValues setObject:[NSNumber numberWithFloat:[pixelData intensityMedian]] forKey:[NSNumber numberWithInteger:[[roiValueTagMasks objectAtIndex:i] integerValue] + MedianValueTagMask]];
    }
    
    DCMView *dcmView = [[[self volumeWindow] viewerController] imageView];
    [replacementValues setObject:[NSNumber numberWithInteger:(NSInteger) [[dcmView dcmPixList] count] - [dcmView curImage]] forKey:[NSNumber numberWithInteger:SliceNumberValueTag]];
    
    return replacementValues;
}

- (NSString *)_stringValueFromDicomGroup:(int)group element:(int)element;
{
    ViewerController *viewerController = [self.volumeWindow viewerController];
    
    NSArray *pixList = [viewerController pixList: 0];
    long    curSlice = [[viewerController imageView] curImage];
    DCMPix  *curPix = [pixList objectAtIndex: curSlice];
    NSString    *file_path = [curPix sourceFile];
        
    DCMObject   *dcmObj = [DCMObject objectWithContentsOfFile:file_path decodingPixelData:NO];
    
    DCMAttributeTag *tag = [DCMAttributeTag tagWithGroup:group element:element];
    
    if (tag)  {
        DCMAttribute *attr = [dcmObj attributeForTag:tag];
        return [[attr value] description];
    }
    return nil;
}

- (NSString *)_stringForISOLatinEncoding:(NSString *)string
{
    if (!string)
        return nil;
    
    NSMutableString *transformedString = [NSMutableString stringWithString:string];
    
    CFStringTransform((CFMutableStringRef)transformedString, NULL, kCFStringTransformToLatin, NO);
    CFStringTransform((CFMutableStringRef)transformedString, NULL, kCFStringTransformStripCombiningMarks, NO);
    CFStringTransform((CFMutableStringRef)transformedString, NULL, kCFStringTransformStripDiacritics, NO);
    CFStringTransform((CFMutableStringRef)transformedString, NULL, kCFStringTransformToUnicodeName, NO);
    
    return transformedString;
}

- (NSString *)_stringByEncodingXMLCharacters:(NSString *)string
{
    NSMutableString *mutableString = [string mutableCopy];
    [mutableString replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange(0, [mutableString length])];
    [mutableString replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange(0, [mutableString length])];
    [mutableString replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange(0, [mutableString length])];

    return mutableString;
}


- (CGFloat)_maskVolume:(OSIROIMask *)roiMask floatVolumeData:(OSIFloatVolumeData *)floatVolumeData
{
    NSValue *maskRunValue;
    NSUInteger maskIndexCount = 0;
    
    for (maskRunValue in [roiMask maskRuns]) {
        maskIndexCount += [maskRunValue OSIROIMaskRunValue].widthRange.length;
    }
    
    CGFloat voxelSize = floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * floatVolumeData.pixelSpacingZ * 0.001;
    return voxelSize * (CGFloat)maskIndexCount;
}

- (CGFloat)_maskArea:(OSIROIMask *)roiMask floatVolumeData:(OSIFloatVolumeData *)floatVolumeData
{
    NSValue *maskRunValue;
    NSUInteger maskIndexCount = 0;
    
    for (maskRunValue in [roiMask maskRuns]) {
        maskIndexCount += [maskRunValue OSIROIMaskRunValue].widthRange.length;
    }
    
    CGFloat pixelSize = floatVolumeData.pixelSpacingX * floatVolumeData.pixelSpacingY * 0.01;
    return pixelSize * (CGFloat)maskIndexCount;
}

// start and end are in the mask space, even though they are floats
+ (NSArray *)_maskIndexPointsOnLineFrom:(N3Vector)start to:(N3Vector)end
{
    // return points on a line inspired by Bresenham's line algorithm
    
    N3Vector direction;
    N3Vector absDirection;
    N3Vector principleDirection;
    N3Vector secondaryDirection;
    N3Vector tertiaryDirection;
    
    direction = N3VectorSubtract(end, start);
    absDirection.x = ABS(direction.x);
    absDirection.y = ABS(direction.y);
    absDirection.z = ABS(direction.z);
    
    principleDirection = N3VectorZero;
    secondaryDirection = N3VectorZero;
    tertiaryDirection = N3VectorZero;
    
    if (absDirection.x > absDirection.y && absDirection.x > absDirection.z) {
        principleDirection.x = 1;
        secondaryDirection.y = 1;
        tertiaryDirection.z = 1;
    } else if (absDirection.y > absDirection.x && absDirection.y > absDirection.z) {
        principleDirection.y = 1;
        secondaryDirection.x = 1;
        tertiaryDirection.z = 1;
    } else {
        principleDirection.z = 1;
        secondaryDirection.x = 1;
        tertiaryDirection.y = 1;
    }
        
    if (CMRVectorSumElements(CMRVectorMutiplyElements(direction, principleDirection)) == 0) {
        if (start.x >= 0 && start.y >= 0 && start.z >= 0) {
            OSIROIMaskIndex maskIndex;
            maskIndex.x = round((double)start.x);
            maskIndex.y = round((double)start.y);
            maskIndex.z = round((double)start.z);
            
            return [NSArray arrayWithObject:[NSValue valueWithOSIROIMaskIndex:maskIndex]];
        } else {
            return [NSArray array];
        }
    }
    
    N3Vector secondarySlope = N3VectorScalarMultiply(secondaryDirection, CMRVectorSumElements(CMRVectorMutiplyElements(direction, secondaryDirection)) /
                                                     ABS(CMRVectorSumElements(CMRVectorMutiplyElements(direction, principleDirection))));
    N3Vector tertiarySlope = N3VectorScalarMultiply(tertiaryDirection, CMRVectorSumElements(CMRVectorMutiplyElements(direction, tertiaryDirection)) /
                                                     ABS(CMRVectorSumElements(CMRVectorMutiplyElements(direction, principleDirection))));

    NSInteger endIndex = round((double)CMRVectorSumElements(CMRVectorMutiplyElements(end, principleDirection)));
    NSInteger currentIndex = round((double)CMRVectorSumElements(CMRVectorMutiplyElements(start, principleDirection)));
    BOOL goingForward = (CMRVectorSumElements(CMRVectorMutiplyElements(direction, principleDirection)) > 0);
    
    NSUInteger i;
    NSMutableArray *maskIndexArray = [NSMutableArray array];
    for (i = 0; goingForward ? currentIndex < endIndex : currentIndex > endIndex; i++) {
        N3Vector maskVector = start;
        if (goingForward) {
            maskVector = N3VectorAdd(maskVector, N3VectorScalarMultiply(principleDirection, (CGFloat)i));
        } else {
            maskVector = N3VectorAdd(maskVector, N3VectorScalarMultiply(principleDirection, -(CGFloat)i));
        }
        maskVector = N3VectorAdd(maskVector, N3VectorScalarMultiply(secondarySlope, (CGFloat)i));
        maskVector = N3VectorAdd(maskVector, N3VectorScalarMultiply(tertiarySlope, (CGFloat)i));
        
        maskVector.x = round((double)maskVector.x);
        maskVector.y = round((double)maskVector.y);
        maskVector.z = round((double)maskVector.z);
        
        currentIndex = round((double)CMRVectorSumElements(CMRVectorMutiplyElements(maskVector, principleDirection)));
        
        if (maskVector.x >= 0 && maskVector.y >= 0 && maskVector.z >= 0) {
            OSIROIMaskIndex maskIndex;
            maskIndex.x = maskVector.x;
            maskIndex.y = maskVector.y;
            maskIndex.z = maskVector.z;
            
            [maskIndexArray addObject:[NSValue valueWithOSIROIMaskIndex:maskIndex]];
        }
        
    }
    
    return maskIndexArray;
}

// start and end are in the mask space, even though they are floats
+ (CGFloat)_infarctTransmuralityOnLineFrom:(N3Vector)start to:(N3Vector)end mycardiumMask:(OSIROIMask *)mycardiumMask infarctMask:(OSIROIMask *)infarctMask
{
    NSArray *maskPoints = [self _maskIndexPointsOnLineFrom:start to:end];
    
    NSUInteger myocardiumWidth = 0;
    NSUInteger infarctWidth = 0;
    
    for (NSValue *indexValue in maskPoints) {
        OSIROIMaskIndex maskIndex = [indexValue OSIROIMaskIndexValue];
        if ([mycardiumMask indexInMask:maskIndex]) {
            myocardiumWidth++;
            if ([infarctMask indexInMask:maskIndex]) {
                infarctWidth = myocardiumWidth;
            }
        }
    }
    
    if (myocardiumWidth) {
        return (CGFloat)infarctWidth/(CGFloat)myocardiumWidth;
    } else {
        return 0;
    }
}

// step angle is in radians, vectors are in dicom space
+ (BOOL)_infarctTransmuralityForMyocardiumMask:(OSIROIMask *)mycardiumMask infarctMask:(OSIROIMask*)infarctMask firstLineStart:(N3Vector)firstLineStart firstLineEnd:(N3Vector)firstLineEnd
secondLineStart:(N3Vector)secondLineStart secondLineEnd:(N3Vector)secondLineEnd useWideAngle:(BOOL)useWideAngle stepAngle:(CGFloat)stepAngle
sectorLineStart:(N3Vector)sectorLineStart sectorLineEnd:(N3Vector)sectorLineEnd sectorCount:(NSInteger)sectorCount sector:(NSInteger)sector volumeTransform:(N3AffineTransform)volumeTransform
minTransmurality:(CGFloat*)minTransmurality maxTransmurality:(CGFloat*)maxTransmurality meanTransmurality:(CGFloat*)meanTransmurality
{
    N3Vector firstDirectionVector = N3VectorSubtract(firstLineEnd, firstLineStart);
    N3Vector secondDirectionVector = N3VectorSubtract(secondLineEnd, secondLineStart);
    N3Vector normalizedFirstDiretionVector = N3VectorNormalize(firstDirectionVector);
    
    CGFloat firstLineLength = N3VectorLength(firstDirectionVector);
    CGFloat secondLineLength = N3VectorLength(secondDirectionVector);
    
    N3Vector rotationVector = N3VectorNormalize(N3VectorCrossProduct(firstDirectionVector, secondDirectionVector));
    CGFloat swipeAngle = 0;
    
    swipeAngle = acos((double)MIN(MAX(N3VectorDotProduct(N3VectorNormalize(firstDirectionVector), N3VectorNormalize(secondDirectionVector)), -1.0), 1.0));
    if (useWideAngle) {
        rotationVector = N3VectorInvert(rotationVector);
        swipeAngle = (2*M_PI) - swipeAngle;
    }
    
    NSUInteger rayCount = floor((double)swipeAngle / stepAngle);
    NSUInteger i;
    
    CGFloat sectorWidth = 0;
    CGFloat sectorStartAngle = 0;
    CGFloat sectorEndAngle = 0;
    N3Vector upVector = N3VectorZero;
    N3Vector sectorLineVector;
    if (sectorCount && sector != -1) {
        sectorWidth = 2.0 * M_PI / (CGFloat)sectorCount;
        upVector = N3VectorApplyTransformToDirectionalVector(N3VectorMake(0, 0, -1), N3AffineTransformInvert(volumeTransform));
        NSInteger sectorIndex = (sector + sectorCount - 2) % sectorCount;
        sectorStartAngle = sectorWidth * (CGFloat)sectorIndex;
        sectorEndAngle = sectorStartAngle + sectorWidth;
        sectorLineVector = N3VectorSubtract(sectorLineEnd, sectorLineStart);
    }
    
    double *transmuralities = NULL;
    NSUInteger transmuralitiesCount = 0;
    transmuralities = malloc(rayCount * sizeof(double));
    memset(transmuralities, 0, rayCount * sizeof(double));
    
    for (i = 0; i < rayCount; i++) {
        CGFloat interpCompement = 0;
        if (rayCount > 1) {
            interpCompement = (CGFloat)i/((CGFloat)rayCount - 1.0);
        }
        CGFloat interpValue = 1.0 - interpCompement;
        
        N3Vector startVector = N3VectorLerp(firstLineStart, secondLineStart, interpValue);
        N3Vector directionVector = N3VectorApplyTransform(normalizedFirstDiretionVector, N3AffineTransformMakeRotationAroundVector((CGFloat)i*stepAngle, rotationVector));
        CGFloat length = interpValue*firstLineLength + interpCompement*secondLineLength;
        N3Vector endVector = N3VectorAdd(startVector, N3VectorScalarMultiply(directionVector, length));
        
        // don't use this line if endpoint is not within the desired sector
        if (sectorCount && sector != -1) {
            CGFloat angle = N3VectorAngleBetweenVectorsAroundVector(sectorLineVector, N3VectorSubtract(endVector, sectorLineStart), upVector);
            if (angle < sectorStartAngle || angle >= sectorEndAngle) {
                continue;
            }
        }
        
        N3Vector startMaskVector = N3VectorApplyTransform(startVector, volumeTransform);
        startMaskVector.x -= 0.5;
        startMaskVector.y -= 0.5;
        N3Vector endMaskVector = N3VectorApplyTransform(endVector, volumeTransform);
        endMaskVector.x -= 0.5;
        endMaskVector.y -= 0.5;
        
        transmuralities[transmuralitiesCount] = [self _infarctTransmuralityOnLineFrom:startMaskVector to:endMaskVector mycardiumMask:mycardiumMask infarctMask:infarctMask];
        transmuralitiesCount++;
    }

    double tempDouble = 0;
    if (minTransmurality) {
        vDSP_minvD(transmuralities, 1, &tempDouble, transmuralitiesCount);
        *minTransmurality = tempDouble;
    }
    
    if (maxTransmurality) {
        vDSP_maxvD(transmuralities, 1, &tempDouble, transmuralitiesCount);
        *maxTransmurality = tempDouble;
    }
    
    if (meanTransmurality) {
        vDSP_meanvD(transmuralities, 1, &tempDouble, transmuralitiesCount);
        *meanTransmurality = tempDouble;
    }
    
    free(transmuralities);

    return YES;
}

- (IBAction)generateMissingROIs:(id)sender
{
	long				i, x;
	float				preLocation, interval;
	NSMutableArray		*selectedRois = [NSMutableArray array];
    ViewerController *viewerController = self.volumeWindow.viewerController;
    OSIROIManager *roiManager = self.volumeWindow.ROIManager;
	
	[viewerController computeInterval];
	
	[viewerController displayAWarningIfNonTrueVolumicData];
	
	for( i = 0; i < [viewerController maxMovieIndex]; i++)
		[viewerController saveROI: i];
	
    NSSet *osiriXROIs;
    osiriXROIs = [[roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium"] osiriXROIs];
    if ([osiriXROIs count]) {
        [selectedRois addObjectsFromArray:[osiriXROIs allObjects]];
    }
    osiriXROIs = [[roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Endocardium"] osiriXROIs];
    if ([osiriXROIs count]) {
        [selectedRois addObjectsFromArray:[osiriXROIs allObjects]];
    }
    osiriXROIs = [[roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: LV/RV"] osiriXROIs];
    if ([osiriXROIs count]) {
        [selectedRois addObjectsFromArray:[osiriXROIs allObjects]];
    }
    osiriXROIs = [[roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Remote_stddev_"] osiriXROIs];
    if ([osiriXROIs count]) {
        [selectedRois addObjectsFromArray:[osiriXROIs allObjects]];
    }
    osiriXROIs = [[roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Infarct Start Angle"] osiriXROIs];
    if ([osiriXROIs count]) {
        [selectedRois addObjectsFromArray:[osiriXROIs allObjects]];
    }
    osiriXROIs = [[roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Infarct End Angle"] osiriXROIs];
    if ([osiriXROIs count]) {
        [selectedRois addObjectsFromArray:[osiriXROIs allObjects]];
    }
            	
	if([selectedRois count] == 0)
	{
		NSRunCriticalAlertPanel(NSLocalizedString(@"Generate Missing ROIs Error", nil), NSLocalizedString(@"There are no CMRSegTools ROIs", nil) , NSLocalizedString(@"OK", nil), nil, nil);
		return;
	}
	
	// Check that sliceLocation is available and identical for all images
	preLocation = 0;
	interval = 0;
	
	for( x = 0; x < [[viewerController pixList] count]; x++)
	{
		DCMPix *curPix = [[viewerController pixList] objectAtIndex: x];
		
		if( preLocation != 0)
		{
			if( interval)
			{
                if( fabs( [curPix sliceLocation] - preLocation - interval) > 1.0)
                {
                    NSRunCriticalAlertPanel(NSLocalizedString(@"ROIs Volume Error", nil), NSLocalizedString(@"Slice Interval is not constant!", nil) , NSLocalizedString(@"OK", nil), nil, nil);
                    return;
                }
			}
			interval = [curPix sliceLocation] - preLocation;
		}
		preLocation = [curPix sliceLocation];
	}
	
	NSLog(@"Slice Interval : %f", interval);
	
    if( [sender tag] == 0) // Compute Volume
    {
        if( interval == 0)
        {
            NSRunCriticalAlertPanel(NSLocalizedString(@"ROIs Volume Error", nil), NSLocalizedString(@"Slice Locations not available to compute a volume.", nil) , NSLocalizedString(@"OK", nil), nil, nil);
            return;
        }
	}
        
	[viewerController addToUndoQueue: @"roi"];
	
	WaitRendering *splash = [[WaitRendering alloc] init:NSLocalizedString(@"Preparing data...", nil)];
	[splash showWindow:self];
	
	// First generate the missing ROIs
	NSMutableArray *generatedROIs = [NSMutableArray array];
	
    for (ROI *selectedRoi in selectedRois) {
        [self generateROIs:selectedRoi generatedROIs:generatedROIs];
    }

    // Uncomment this to run BEAS on all the interpolated ROIs
//    for( x = 0; x < [[viewerController pixList] count]; x++) {
//        [self runBEASOnMovieIndex:[viewerController curMovieIndex] pixIndex:x];
//    }
    
    [[CMRSegTools sharedInstance] updateCMRForVolumeWindow:self.volumeWindow];
    
	[splash close];
	[splash autorelease];
}

- (void)generateROIs:(ROI*)selectedRoi generatedROIs:(NSMutableArray*)generatedROIs
{
	long				i, x, y, imageCount, lastImageIndex;
	ROI					*lastROI;
    ViewerController *viewerController = self.volumeWindow.viewerController;
	
	lastROI = nil;
	lastImageIndex = -1;
		
    [viewerController roiDeleteGeneratedROIsForName: [selectedRoi name]];
		
    for( x = 0; x < [[viewerController pixList] count]; x++)
    {
        imageCount = 0;
        
        for( i = 0; i < [[[viewerController roiList] objectAtIndex: x] count]; i++)
        {
            ROI	*curROI = [[[viewerController roiList] objectAtIndex: x] objectAtIndex: i];
            
            if( [[curROI name] isEqualToString: [selectedRoi name]])
            {
                imageCount++;
                
                if( lastROI && (lastImageIndex+1) < x)
                {
                    for( y = lastImageIndex+1; y < x; y++)
                    {
                        ROI	*c = [viewerController roiMorphingBetween: lastROI  and: curROI ratio: (float) (y - lastImageIndex) / (float) (x - lastImageIndex)];
                        
                        if( c)
                        {
                            [c setComments: @"morphing generated"];
                            [c setName: [selectedRoi name]];
#                           pragma clang diagnostic push
#                           pragma clang diagnostic ignored "-Wdeprecated-declarations"
                            [[viewerController imageView] roiSet: c];
#                           pragma clang diagnostic pop
                            [[[viewerController roiList] objectAtIndex: y] addObject: c];
                            
                            [generatedROIs addObject: c];
                            [[NSNotificationCenter defaultCenter] postNotificationName:OsirixAddROINotification object:self
                                                                              userInfo:@{@"ROI": c, @"sliceNumber": [NSNumber numberWithLong:x]}];
                        }
                    }
                }
                
                lastImageIndex = x;
                lastROI = curROI;
            }
        }
    }
}

- (void)menuWillOpen:(NSMenu*)menu {
    if (menu == self.histogramView.menu) {
        NSInteger histogramBinsCountChoice = self.histogramBinsCountChoice;
        
        [menu removeAllItems];
        NSMenuItem* mi;
        if (histogramBinsCountChoice == 0) {
            mi = [menu addItemWithTitle:NSLocalizedString(@"The number of bins is currently unspecified", nil) action:nil keyEquivalent:@""];
        } else {
            mi = [menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%d bins", nil), histogramBinsCountChoice] action:nil keyEquivalent:@""];
        }
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        mi = [menu addItemWithTitle:NSLocalizedString(@"Set...", nil) action:@selector(setHistogramBinsCountAction:) keyEquivalent:@""];
        mi.target = self;
        
        if (histogramBinsCountChoice != 0) {
            mi = [menu addItemWithTitle:NSLocalizedString(@"Revert to unspecified", nil) action:@selector(unsetHistogramBinsCountAction:) keyEquivalent:@""];
            mi.target = self;
        }
    }
}

+ (NSAlert *)promptWithText:(NSString *)prompt messageText:(NSString *)messageText defaultButton:(NSString *)defaultButtonTitle alternateButton:(NSString *)alternateButtonTitle otherButton:(NSString *)otherButtonTitle informativeTextWithFormat:(NSString *)informativeText, ... {
    NSString* formattedInformativeText = @"";
    if (informativeText) {
        va_list val;
        va_start(val, informativeText);
        formattedInformativeText = [[NSString alloc] initWithFormat:informativeText arguments:val];
        va_end(val);
    }
    
    NSAlert* alert = [[[NSAlert alloc] init] autorelease];
    alert.messageText = messageText;
    
    NSButton *ok = [alert addButtonWithTitle:(defaultButtonTitle? defaultButtonTitle : NSLocalizedString(@"OK", nil))];
    ok.tag = NSAlertDefaultReturn;
    
    if (alternateButtonTitle) {
        NSButton *cancel = [alert addButtonWithTitle:alternateButtonTitle];
        cancel.tag = NSAlertAlternateReturn;
        cancel.keyEquivalent = @"\e";
    }
    
    if (otherButtonTitle) {
        NSButton *other = [alert addButtonWithTitle:otherButtonTitle];
        other.tag = NSAlertOtherReturn;
    }
    
    if (informativeText && formattedInformativeText)
        alert.informativeText = formattedInformativeText;
    
    NSTextField *textField = [[[NSTextField alloc] init] autorelease];
    textField.stringValue = prompt;
    textField.autoresizingMask = NSViewWidthSizable;
    [textField sizeToFit];
    
    NSTextField *label = nil;
    for (id view in [[alert.window contentView] subviews])
        if ([view isKindOfClass:[NSTextField class]])
            label = view;
    
    NSRect frame = textField.frame;
    frame.size.width = label.frame.size.width;
    textField.frame = frame;
    
    alert.accessoryView = textField;
    
    return alert;
}

- (IBAction)setHistogramBinsCountAction:(id)sender {
    NSInteger val = self.histogramBinsCountChoice;
    if (!val)
        val = [_histogramView binCount];
    
    [[self.class promptWithText:[NSString stringWithFormat:@"%d", (int)val]
                    messageText:NSLocalizedString(@"How many bins shall the histogram have?", nil)
                  defaultButton:nil alternateButton:NSLocalizedString(@"Cancel", nil) otherButton:nil
      informativeTextWithFormat:nil]
     beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(setHistogramBinsCountPromptDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)unsetHistogramBinsCountAction:(id)sender {
    [self setHistogramBinsCountChoice:0];
}

- (void)setHistogramBinsCountPromptDidEnd:(NSAlert*)alert returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo {
    if (returnCode != NSAlertDefaultReturn)
        return;
    
    NSTextField *textField = ([alert.accessoryView isKindOfClass:NSTextField.class]? (id)alert.accessoryView : nil);
    NSInteger val = [textField.stringValue integerValue];
    if (val < 0)
        val = 0;
    
    [self setHistogramBinsCountChoice:val];
}

- (void)setHistogramBinsCountChoice:(NSInteger)histogramBinsCountChoice {
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    NSString *component;
    NSInteger i;
    OSIROI *outsideROI = [roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium"]; // use the name prefix because we will tag other info to this name
    
    if (outsideROI) {
        NSArray *epiNameComponents = [[outsideROI name] componentsSeparatedByString:@";"];
        NSMutableArray *newEpiNameComponents = [NSMutableArray array];
        
        for (component in epiNameComponents) {
            if ([component hasPrefix:@"Bins_"] == NO) {
                [newEpiNameComponents addObject:component];
            }
        }
        if (histogramBinsCountChoice > 0) {
            [newEpiNameComponents addObject:[NSString stringWithFormat:@"Bins_%d", (int)histogramBinsCountChoice]];
        }
        
        NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: Epicardium"];
        for (i = 1; i < [newEpiNameComponents count]; i++) {
            [newName appendFormat:@";%@", [newEpiNameComponents objectAtIndex:i]];
        }
        
        if ([[outsideROI name] isEqualToString:newName] == NO) {
            ROI* osirixROI = [[outsideROI osiriXROIs] anyObject];
            [osirixROI setName:newName];
        }
    }
}

- (NSInteger)histogramBinsCountChoice {
    OSIROIManager *roiManager = [self.volumeWindow ROIManager];
    OSIROI *outsideROI = [roiManager CMRFirstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium"]; // use the name prefix because we will tag other info to this name

    if (outsideROI) {
        for (NSString* component in [[outsideROI name] componentsSeparatedByString:@";"])
            if ([component hasPrefix:@"Bins_"])
                return [[component substringFromIndex:[@"Bins_" length]] integerValue];
    }
    
    return 0;
}



@end




































