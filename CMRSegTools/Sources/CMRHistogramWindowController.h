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
//  CMRHistogramWindowController.h
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 10/11/12.
//  Copyright (c) 2012 Spaltenstein Natural Image. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CMRHistogramView.h"
#import "CMRSegToolsStep.h"

#import <OsiriX/OSIGeometry.h>

@class OSIVolumeWindow;
@class CMRHistogramView;
@class CMRActivityButton;
@class CMRImageButton;

typedef NS_ENUM(NSInteger, CMRHistogramWindowSegmentationStatisticsLabels) {
    CMRHistogramWindowSegmentationNoStatisticsLabels = 0,
    CMRHistogramWindowSegmentationRegionStatisticsLabels,
    CMRHistogramWindowSegmentationFWHMStatisticsLabels
};

@interface CMRPixelStatisticsPane : NSView
{
    NSLayoutConstraint *heightConstraint;
}
@property (nonatomic, readwrite, assign) NSLayoutConstraint *heightConstraint;
- (IBAction)discosureTriangle:(id)sender;
@end

@interface CMRROIEditingPane : NSView
{
    NSLayoutConstraint *heightConstraint;
}
@property (nonatomic, readwrite, assign) NSLayoutConstraint *heightConstraint;
- (IBAction)discosureTriangle:(id)sender;
@end

//typedef enum : NSUInteger {
//    CMRClickDrawNone = 0,
//    CMRClickDrawModeIncludeROI,
//    CMRClickDrawModeNoReflowROI,
//    CMRClickDrawModeExcludeROI,
//} CMRClickDrawMode;

@interface CMRHistogramWindowController : NSWindowController <CMRHistogramViewDelegate, CMRSegToolsStepDelegate, NSMenuDelegate>
{
    OSIVolumeWindow *_volumeWindow;
    CMRHistogramView *_histogramView;
    CMRImageButton *_histogramBinsButton;
    
//    NSInteger _histogramBinsCountChoice;
    
    NSButton* currentStickyButton; // no retaining here

    CMRPixelStatisticsPane *pixelStatisticsPane;
    NSView *histogramPane;
    CMRROIEditingPane *roiEditingPane;

    CMRHistogramWindowSegmentationStatisticsLabels displayedStatisticsLabels;
    NSView *statisticsLabelsView;
    NSView *regionStatisticsLabelsPane;
    NSView *FWHMStatisticsLabelsPane;

    NSTextField *section1NonMI;
    NSTextField *section2NonMI;
    NSTextField *section3NonMI;
    NSTextField *section4NonMI;
    NSTextField *section5NonMI;
    NSTextField *section6NonMI;
    
    NSTextField *section1MI;
    NSTextField *section2MI;
    NSTextField *section3MI;
    NSTextField *section4MI;
    NSTextField *section5MI;
    NSTextField *section6MI;
    
    NSTextField *section1NR;
    NSTextField *section2NR;
    NSTextField *section3NR;
    NSTextField *section4NR;
    NSTextField *section5NR;
    NSTextField *section6NR;

    NSPopUpButton *statisticsSelectorPopUp;
    NSMenuItem *sector1MenuItem;
    NSMenuItem *sector2MenuItem;
    NSMenuItem *sector3MenuItem;
    NSMenuItem *sector4MenuItem;
    NSMenuItem *sector5MenuItem;
    NSMenuItem *sector6MenuItem;

    NSTextField *myocardiumArea;
    NSTextField *myocardiumMean;
    NSTextField *myocardiumStddev;
    NSTextField *myocardiumIQR;
    NSTextField *myocardiumMedian;
    NSTextField *myocardiumMin;
    NSTextField *myocardiumMax;
    
    NSTextField *percentNonMI3D;
    NSTextField *areaNonMI3D;
    NSTextField *weightNonMI3D;
    NSTextField *volumeNonMI3D;
    NSTextField *percentMI3D;
    NSTextField *areaMI3D;
    NSTextField *weightMI3D;
    NSTextField *volumeMI3D;
    NSTextField *percentNR3D;
    NSTextField *areaNR3D;
    NSTextField *weightNR3D;
    NSTextField *volumeNR3D;
    
    NSTextField *percentNonMI2D;
    NSTextField *areaNonMI2D;
    NSTextField *weightNonMI2D;
    NSTextField *volumeNonMI2D;
    NSTextField *percentMI2D;
    NSTextField *areaMI2D;
    NSTextField *weightMI2D;
    NSTextField *volumeMI2D;
    NSTextField *percentNR2D;
    NSTextField *areaNR2D;
    NSTextField *weightNR2D;
    NSTextField *volumeNR2D;
    
    NSTextField *ESLLabel;
    NSTextField *ESLTextLabel;
    NSTextField *ESALabel;
    NSTextField *ESASurfaceLabel;
    NSTextField *ESATextLabel;

    NSTextField *visibleOnlyLabel;

    NSTextField *minTransmurality;
    NSTextField *minTransmuralityLabel;
    NSTextField *maxTransmurality;
    NSTextField *maxTransmuralityLabel;
    NSTextField *meanTransmurality;
    NSTextField *meanTransmuralityLabel;

    CMRActivityButton *quickDrawButton;

    CMRActivityButton *epicardiumButton;
    CMRActivityButton *endocardiumButton;
    CMRActivityButton *LVRVButton;
    NSButton *drawSegmentsCheckbox;
    NSTextField *drawSegmentsLabel;
    
    CMRActivityButton *runBEASButton;

    NSButton *histogramThresholdCheckbox;
    NSTextField *histogramThresholdTextLabel;
//    NSTextField *histogramThresholdLabel;

    NSStepper *stddevStepper;
    NSTextField *stddevTextField;
    NSTextField *stddevLabel;
    NSStepper *segmentStepper;
    NSTextField *segmentTextField;
    NSTextField *segmentLabel;
    NSTextField *meanLabel;
    NSTextField *sigmaLabel;
    NSTextField *remoteThresholdLabel;
    NSTextField *meanTextLabel;
    NSTextField *sigmaTextLabel;
    NSTextField *thresholdTextLabel;
    
    CMRActivityButton *angleWiperButton;
    
    NSPopUpButton *popUpSegmentation;
    NSProgressIndicator *popUpSegmentationProgressIndicator;
    NSTextField *meanTextLabelFWHM;
    NSTextField *ImaxTextLabelFWHM;
    NSTextField *thresholdTextLabelFWHM;
    NSTextField *meanLabelFWHM;
    NSTextField *ImaxLabelFWHM;
    NSTextField *remoteThresholdLabelFWHM;
    NSTextField *remoteMessage;
    NSTextField *withNR;
    NSButton *NRCheckbox;

    NSButton *pixelStatisticsDisclosure;
    NSButton *roiEditingDisclosure;

    CMRActivityButton *growIncludeRegionButton;
    
    CMRActivityButton *includeROIButton;
    
    CMRActivityButton *excludeROIButton;
    
    CMRActivityButton *noReflowROIButton;
    
    CMRActivityButton *growNoReflowRegionButton;
    
    NSPopUpButton *sectionNumberPopUpButton;

    NSButton *importROIsButton;
    NSButton *importCheckbox;
    CMRSegToolsStep *activeStep;
}

@property (nonatomic, readonly, retain) OSIVolumeWindow *volumeWindow;
@property (nonatomic, readwrite, retain) IBOutlet CMRHistogramView *histogramView;
@property (nonatomic, readwrite, retain) IBOutlet CMRImageButton *histogramBinsButton;

@property (nonatomic, readwrite, retain) IBOutlet CMRPixelStatisticsPane *pixelStatisticsPane;
@property (nonatomic, readwrite, retain) IBOutlet NSView *histogramPane;
@property (nonatomic, readwrite, retain) IBOutlet CMRROIEditingPane *roiEditingPane;

@property (nonatomic, readwrite, assign) IBOutlet NSView *statisticsLabelsView;
@property (nonatomic, readwrite, retain) IBOutlet NSView *regionStatisticsLabelsPane;
@property (nonatomic, readwrite, retain) IBOutlet NSView *FWHMStatisticsLabelsPane;
@property (nonatomic, readwrite, assign) CMRHistogramWindowSegmentationStatisticsLabels displayedStatisticsLabels;

@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section1NonMI;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section2NonMI;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section3NonMI;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section4NonMI;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section5NonMI;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section6NonMI;

@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section1MI;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section2MI;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section3MI;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section4MI;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section5MI;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section6MI;

@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section1NR;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section2NR;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section3NR;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section4NR;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section5NR;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *section6NR;

@property (nonatomic, readwrite, assign) IBOutlet NSPopUpButton *statisticsSelectorPopUp;
@property (nonatomic, readwrite, assign) IBOutlet NSMenuItem *sector1MenuItem;
@property (nonatomic, readwrite, assign) IBOutlet NSMenuItem *sector2MenuItem;
@property (nonatomic, readwrite, assign) IBOutlet NSMenuItem *sector3MenuItem;
@property (nonatomic, readwrite, assign) IBOutlet NSMenuItem *sector4MenuItem;
@property (nonatomic, readwrite, assign) IBOutlet NSMenuItem *sector5MenuItem;
@property (nonatomic, readwrite, assign) IBOutlet NSMenuItem *sector6MenuItem;

@property (nonatomic, readwrite, assign) IBOutlet NSTextField *myocardiumArea;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *myocardiumMean;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *myocardiumStddev;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *myocardiumIQR;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *myocardiumMedian;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *myocardiumMin;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *myocardiumMax;

@property (nonatomic, readwrite, assign) IBOutlet NSTextField *percentNonMI3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *areaNonMI3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *weightNonMI3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *volumeNonMI3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *percentMI3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *areaMI3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *weightMI3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *volumeMI3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *percentNR3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *areaNR3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *weightNR3D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *volumeNR3D;

@property (nonatomic, readwrite, assign) IBOutlet NSTextField *percentNonMI2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *areaNonMI2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *weightNonMI2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *volumeNonMI2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *percentMI2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *areaMI2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *weightMI2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *volumeMI2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *percentNR2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *areaNR2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *weightNR2D;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *volumeNR2D;

@property (nonatomic, readwrite, assign) IBOutlet NSTextField *ESLLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *ESLTextLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *ESALabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *ESASurfaceLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *ESATextLabel;

@property (nonatomic, readwrite, assign) IBOutlet NSTextField *visibleOnlyLabel;

@property (nonatomic, readwrite, assign) IBOutlet NSTextField *minTransmurality;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *minTransmuralityLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *maxTransmurality;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *maxTransmuralityLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *meanTransmurality;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *meanTransmuralityLabel;

@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *quickDrawButton;

@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *epicardiumButton;
@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *endocardiumButton;
@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *LVRVButton;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *drawSegmentsCheckbox;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *drawSegmentsLabel;

@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *runBEASButton;

@property (nonatomic, readwrite, assign) IBOutlet NSButton *histogramThresholdCheckbox;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *histogramThresholdTextLabel;
//@property (nonatomic, readwrite, assign) IBOutlet NSTextField *histogramThresholdLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *histogramRangeMinField, *histogramRangeMaxField, *histogramRangeToLabel;

@property (nonatomic, readwrite, assign) IBOutlet NSStepper *stddevStepper;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *stddevTextField;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *stddevLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSStepper *segmentStepper;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *segmentTextField;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *segmentLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *meanLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *sigmaLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *remoteThresholdLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *meanTextLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *sigmaTextLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *thresholdTextLabel;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *remoteMessage;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *withNR;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *NRCheckbox;

@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *angleWiperButton;

@property (nonatomic, readwrite, retain) IBOutlet NSPopUpButton *popUpSegmentation;
@property (nonatomic, readwrite, assign) IBOutlet NSProgressIndicator *popUpSegmentationProgressIndicator;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *meanLabelFWHM;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *ImaxLabelFWHM;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *remoteThresholdLabelFWHM;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *meanTextLabelFWHM;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *ImaxTextLabelFWHM;
@property (nonatomic, readwrite, assign) IBOutlet NSTextField *thresholdTextLabelFWHM;

@property (nonatomic, readwrite, assign) IBOutlet NSButton *pixelStatisticsDisclosure;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *roiEditingDisclosure;

@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *growIncludeRegionButton;

@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *includeROIButton;

@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *excludeROIButton;

@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *noReflowROIButton;

@property (nonatomic, readwrite, assign) IBOutlet CMRActivityButton *growNoReflowRegionButton;

@property (nonatomic, readwrite, assign) IBOutlet NSPopUpButton *sectionNumberPopUpButton;

@property (nonatomic, readwrite, assign) IBOutlet NSButton *importROIsButton;
@property (nonatomic, readwrite, assign) IBOutlet NSButton *importCheckbox;


- (IBAction)updateStatisticSelector:(id)sender;


- (IBAction)updateStddev:(id)sender;
- (IBAction)updateSegment:(id)sender;
- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow;

+ (NSArray *)_maskIndexPointsOnLineFrom:(N3Vector)start to:(N3Vector)end;


@end


@interface CMRHistogramWindowController (Segmentation)
- (IBAction)popUp:(id)sender;
@end

@interface CMRHistogramWindowController (Importer)
- (IBAction)importROIs:(id)sender;
@end


