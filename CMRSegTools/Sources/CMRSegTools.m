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
//  CMRSegTools.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 2/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "CMRSegTools.h"
#import "CMRHiResFloatVolumeData.h"
#import "CMRHistogramWindowController.h"
#import "CMRTextROI.h"
#import "N3BezierPathAdditions.h"
#import "CMRT1Preprocessing.h"
#import <OsiriX/OSIEnvironment.h>
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/OSIMaskROI.h>
#import <OsiriX/OSIPathExtrusionROI.h>
#import <OsiriX/OSIROIFloatPixelData.h>
#import <OsiriX/Notifications.h>
#import <OsiriX/PreferencesWindowController.h>
#import "OsiriX+CMRSegTools.h"
#import <objc/runtime.h>


/**
 * Conditional compilation 
 * prerequisite:
 * - OpenSSL, x86_64
 *
 * User-Defined Settings:
 * - OPENSSL_HEADER_PATH
 * - OPENSSL_LIBRARY_PATH
 */
#if DEBUG == 1
#define ACTIVATION_CODE 0
#else
#define ACTIVATION_CODE 1
#endif

#if ACTIVATION_CODE
    //_______ACTIVATION_CODE_______
    #import <openssl/bio.h>
    #import <openssl/evp.h>
    #import <openssl/hmac.h>
#endif

#import "NSString+Utils.h"
#import "CMRSegToolsActivationCodeWindowController.h"

//_______DEMO_STUDIES_______
#import <OsiriX/DicomStudy.h>
#import <OsiriX/DicomSeries.h>


NSString* const CMRSegToolsROIsDidUpdateNotification = @"CMRSegToolsROIsDidUpdateNotification";

NSString* const CMRSegToolsColorsDidUpdateNotification = @"CMRSegToolsColorsDidUpdateNotification";

NSString* const CMRSegToolsMouseMovedNotification = @"CMRSegToolsMouseMovedNotification";
NSString* const CMRSegToolsMouseDownNotification = @"CMRSegToolsMouseDownNotification";
NSString* const CRMSegToolsDidChangeAnnotationHiddenNotification = @"CRMSegToolsDidChangeAnnotationHiddenNotification";

/* bogus debug code */

//@interface OSIROIMask (CMRBogus)
//- (id)initWithIndexes:(NSArray *)maskIndexes;
//@end
//
/* end bogus debug code */

@class CMRSegTools;
static CMRSegTools* CMRSegToolsSharedInstance = nil;

@interface CMRSegTools ()
- (void)_roisDidUpdateNotification:(NSNotification *)notification;
- (void)_updateCMRForVolumeWindow:(OSIVolumeWindow *)volumeWindow movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex; // update for this specific pix
@end

#if ACTIVATION_CODE

/*
 REFACTOR: Removed for PLoS ONE publication.
 */

#endif


@implementation CMRSegTools

@synthesize annotationHidden = _annotationHidden;

- (void)initPlugin
{
    CMRSegToolsSharedInstance = [self retain];
    
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"OSIEnvironmentActivated"]; // Horos/Osirix (old)
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"OSISharedEnvironmentActivated"]; // OsiriX 8.0.2 (new, maybe earlier than 8.0.2)
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"CMRCursorColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor grayColor]],
                                                               @"CMREpicardiumColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor greenColor]],
                                                               @"CMREndocardiumColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor redColor]],
                                                               @"CMRNoReflowColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor yellowColor]],
                                                               @"CMRRemoteColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor cyanColor]],
                                                               @"CMRFWHMColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor blueColor]],
                                                               @"CMRDistributionColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor orangeColor]],
                                                               @"CMRMIColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor magentaColor]],
                                                               @"CMRHealthyColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor lightGrayColor]],
                                                               @"CMRLVRVColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor yellowColor]],
                                                               @"CMRExcludeColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor grayColor]],
                                                               @"CMRWiperColor": [NSKeyedArchiver archivedDataWithRootObject:[NSColor orangeColor]],
                                                               @"CMRMIColorOpacity": @.25,
                                                               @"CMRNoReflowColorOpacity": @.25,
                                                               @"CMRRemoteColorOpacity": @.25,
                                                               @"CMRFWHMColorOpacity": @.25,
                                                               @"CMROpenPixelStatisticsPane": @YES,
                                                               @"CMROpenROIEditingPane": @YES,
                                                               @"CMRShowSegements": @NO,
                                                               @"CMRInsetEndocardium": @0,
                                                               @"CMRInsetEpicardium": @0,
                                                               @"CMRSetOsirixDefaults": @NO,
                                                               @"CMRSetOsirixDefaults2": @NO,
                                                               @"CMRT1PreprocessingFilters": @[ @{ @"name": @"Magir", @"filter": @"MAGIR" } ],
//                                                               @"CMRT1PreprocessingFilter": @"MAGIR",
//                                                               @"CMRT1PreprocessingFilterType": @0
                                                               }];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMRSetOsirixDefaults"] == NO) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CMRSetOsirixDefaults"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ROITEXTIFSELECTED"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ROITextIfMouseIsOver"];
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMRSetOsirixDefaults2"] == NO) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CMRSetOsirixDefaults2"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ROIDrawPlainEdge"];
    }
    
    { // migrate v1.0.* T1PreprocessingFilter defaults
        NSString *filter = [[NSUserDefaults standardUserDefaults] stringForKey:@"CMRT1PreprocessingFilter"];
        if (filter) {
            NSInteger type = [[NSUserDefaults standardUserDefaults] integerForKey:@"CMRT1PreprocessingFilterType"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CMRT1PreprocessingFilter"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CMRT1PreprocessingFilterType"];
            [[NSUserDefaults standardUserDefaults] setObject:@[@{ @"filter": filter, @"type": @(type) }] forKey:@"CMRT1PreprocessingFilters"];
        }
    }
    
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSImage *prefImage = [[[NSImage alloc] initWithContentsOfURL:[bundle URLForImageResource:@"CMRSegToolsIcon"]] autorelease];
    [PreferencesWindowController addPluginPaneWithResourceNamed:@"CMRSegToolsPreferencePanel" inBundle:bundle
                                                      withTitle:@"CMRSegTools" image:prefImage];
    
//    _lastCMRShowSegements = [[NSUserDefaults standardUserDefaults] boolForKey:@"CMRShowSegements"];
    // for now we are just going to be dumb and recalculate everything that could possibly be out there when an object moves
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_roisDidUpdateNotification:) name:OSIROIManagerROIsDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_roisDidUpdateNotification:) name:CMRSegToolsColorsDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_roisDidUpdateNotification:) name:OsirixUpdateViewNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_roisDidUpdateNotification:) name:OsirixDCMViewIndexChangedNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_roisDidUpdateNotification:) name:OSIEnvironmentOpenVolumeWindowsDidUpdateNotification object:nil];

    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.CMRShowSegements" options:0 context:0];
    
    Method method1, method2;
    method1 = class_getInstanceMethod([DCMView class], @selector(mouseMoved:));
    method2 = class_getInstanceMethod([DCMView class], @selector(CMRSegToolsMouseMoved:));
    method_exchangeImplementations(method1, method2);
    method1 = class_getInstanceMethod([DCMView class], @selector(mouseDown:));
    method2 = class_getInstanceMethod([DCMView class], @selector(CMRSegToolsMouseDown:));
    method_exchangeImplementations(method1, method2);
    method1 = class_getInstanceMethod([DCMView class], @selector(flagsChanged:));
    method2 = class_getInstanceMethod([DCMView class], @selector(CMRSegToolsFlagsChanged:));
    method_exchangeImplementations(method1, method2);
    
    // CMR42EmulationMode OSIMaskROI is not fully implemented, so we do this so we don't hit an assert....
    method1 = class_getInstanceMethod([OSIMaskROI class], @selector(ROIMaskForFloatVolumeData:));
    method2 = class_getInstanceMethod([OSIMaskROI class], @selector(CMRSegToolsROIMaskForFloatVolumeData:));
    method_exchangeImplementations(method1, method2);
    
    // patch super slow implementation in older versions of OsiriX
    method1 = class_getInstanceMethod([OSIROIMask class], @selector(indexInMask:));
    method2 = class_getInstanceMethod([OSIROIMask class], @selector(CMRSegToolsIndexInMask:));
    method_exchangeImplementations(method1, method2);
    
    // patch roiMorphingBetween that can't handle tMesure
    method1 = class_getInstanceMethod([ViewerController class], @selector(roiMorphingBetween:and:ratio:));
    method2 = class_getInstanceMethod([ViewerController class], @selector(CMRSegToolsRoiMorphingBetween:and:ratio:));
    method_exchangeImplementations(method1, method2);
    
    // add toolbar items to the database window
    method_exchangeImplementations(class_getInstanceMethod(BrowserController.class, @selector(toolbarAllowedItemIdentifiers:)),
                                   class_getInstanceMethod(BrowserController.class, @selector(CMRSegTools_toolbarAllowedItemIdentifiers:)));
    method_exchangeImplementations(class_getInstanceMethod(BrowserController.class, @selector(toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:)),
                                   class_getInstanceMethod(BrowserController.class, @selector(CMRSegTools_toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:)));
    
    // add toolbar items to the viewer window
    method_exchangeImplementations(class_getInstanceMethod(ViewerController.class, @selector(toolbarAllowedItemIdentifiers:)),
                                   class_getInstanceMethod(ViewerController.class, @selector(CMRSegTools_toolbarAllowedItemIdentifiers:)));
    method_exchangeImplementations(class_getInstanceMethod(ViewerController.class, @selector(toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:)),
                                   class_getInstanceMethod(ViewerController.class, @selector(CMRSegTools_toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:)));
}

- (void)setMenus {
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    
    NSMenuItem *cstmi = nil;
    for (NSMenuItem *mi in [[[[BrowserController currentBrowser] pluginManagerController] CMRSegTools_ROIToolsMenu] itemArray])
        if (mi.representedObject == bundle) {
            cstmi = mi;
            break;
        }
    
    if (cstmi) {
        NSMenu *database = [[[BrowserController currentBrowser] pluginManagerController] CMRSegTools_DatabaseMenu];
        if (database.numberOfItems == 1 && database.itemArray[0].representedObject == nil)
            [database removeItemAtIndex:0];
        NSMenuItem *mi = [database addItemWithTitle:NSLocalizedString(@"CMR Filtering", nil) action:@selector(CMRT1Preprocessing:) keyEquivalent:@""];
        mi.representedObject = bundle;
        mi.image = cstmi.image;
        mi.target = self;
        mi.submenu = [[[NSMenu alloc] init] autorelease];
        mi.submenu.delegate = self;
    } else {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"Warning: CMRSegTools couldn't add its extra menu item");
        });
    }
}

- (IBAction)CMRT1Preprocessing:(id)sender { // entry point for DATABASE menu and toolbar
    NSDictionary *f = nil;
    if ([[sender representedObject] isKindOfClass:NSDictionary.class])
        f = [sender representedObject];
    
    if (!f)
        f = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"CMRT1PreprocessingFilters"] firstObject];
    
    [CMRT1Preprocessing proceed:f];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem { // this is called for the preprocessing menu only
    return ([[[BrowserController currentBrowser] window] isKeyWindow]);
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)item { // this is called for both the preprocessing and viewer toolbar items
    if (item.action == @selector(CMRT1Preprocessing:))
        return ([[[BrowserController currentBrowser] window] isKeyWindow]);
    
    return YES;
}

- (long)filterImage:(NSString *)menuName { // entry point for VIEWER menu
    [self beginCMRSegToolsWithViewer:viewerController];
    return 0;
}

- (IBAction)CMRSegTools:(id)sender { // entry point for VIEWER toolbar
    [self beginCMRSegToolsWithViewer:[ViewerController frontMostDisplayed2DViewer]];
}

- (void)beginCMRSegToolsWithViewer:(ViewerController *)vc {
    viewerController = vc; // just make sure that the viewerController member is set (maybe not necessary)

    OSIVolumeWindow *volumeWindow = [[OSIEnvironment sharedEnvironment] frontmostVolumeWindow];
    
    if ([self isDataSpacingEven:volumeWindow] == NO) {
        return;
    }
    
    CMRHistogramWindowController *windowController = [[[CMRHistogramWindowController alloc] initWithVolumeWindow:volumeWindow] autorelease];
    [windowController showWindow:self];

    /*
    REFACTOR: Removed for PLoS ONE publication.
    */

    //_______DEPRECATED_______

    // if( [self verifyExecutionMode] )
    // {
    //     OSIVolumeWindow *volumeWindow = [[OSIEnvironment sharedEnvironment] frontmostVolumeWindow];
        
    //     if ([self isDataSpacingEven:volumeWindow] == NO) {
    //         return;
    //     }
        
    //     CMRHistogramWindowController *windowController = [[[CMRHistogramWindowController alloc] initWithVolumeWindow:volumeWindow] autorelease];
    //     [windowController showWindow:self];
    // }
    // else
    // {
        
    //     NSAlert *demoAlert = [NSAlert alertWithMessageText:@"CMRSegTools Activation Code required!"
    //                                          defaultButton:nil
    //                                        alternateButton:nil
    //                                            otherButton:nil
    //                              informativeTextWithFormat:@"Please open a CMRSegTools DEMO study to explore the plug-in functionalities.\n\nTo enable CMRSegTools to process any study, please register on the CMRSegTools website and request an Activation Code.\n"];
    //     [demoAlert setAlertStyle:NSCriticalAlertStyle];
    //     [demoAlert runModal];
         
        
    //     CMRSegToolsActivationCodeWindowController *activationCodeController = [[CMRSegToolsActivationCodeWindowController alloc] init];
    //     [activationCodeController showWindow:self];

    // }

    //_______END_DEPRECATED_______
}

- (BOOL)isDataSpacingEven:(OSIVolumeWindow *)volumeWindow
{
    ViewerController *controller = volumeWindow.viewerController;
	[controller isDataVolumicIn4D: YES]; // Let this function try to correct the scout image first / GE SCAN
	
    double previousInterval3d = 0;
    double minInterval = 0, maxInterval = 0;
    BOOL nonContinuous = NO;
    
    for( int i = 0 ; i < (long)[[controller pixList:0] count] -1; i++)
    {
        double xd = [(DCMPix *)[[controller pixList:0] objectAtIndex: i+1] originX] - [(DCMPix *)[[controller pixList:0] objectAtIndex: i] originX];
        double yd = [(DCMPix *)[[controller pixList:0] objectAtIndex: i+1] originY] - [(DCMPix *)[[controller pixList:0] objectAtIndex: i] originY];
        double zd = [(DCMPix *)[[controller pixList:0] objectAtIndex: i+1] originZ] - [(DCMPix *)[[controller pixList:0] objectAtIndex: i] originZ];
        
        double interval3d = sqrt(xd*xd + yd*yd + zd*zd);
        
        xd /= interval3d;
        yd /= interval3d;
        zd /= interval3d;
        
        int sss = fabs( previousInterval3d - interval3d) * 100.;
        
        if( i == 0)
        {
            maxInterval = fabs( interval3d);
            minInterval = fabs( interval3d);
        }
        else
        {
            if( fabs( interval3d) > maxInterval) maxInterval = fabs( interval3d);
            if( fabs( interval3d) < minInterval) minInterval = fabs( interval3d);
        }
        
        if( sss != 0 && previousInterval3d != 0)
        {
            nonContinuous = YES;
        }
        
        previousInterval3d = interval3d;
    }
    
    if( nonContinuous)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        alert.messageText = NSLocalizedString(@"Warning!", nil);
        alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"These slices have a non regular slice interval, varying from %.3f mm to %.3f mm. This will produce distortion in 3D representations, and in measurements.", nil), minInterval, maxInterval];
        NSButton *ok = [alert addButtonWithTitle:NSLocalizedString(@"Proceed anyway", nil)];
        ok.tag = NSOKButton;
        NSButton *cancel = [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        cancel.tag = NSCancelButton;
        
        [alert beginSheetModalForWindow:controller.window completionHandler:^(NSModalResponse returnCode) {
            if (returnCode != NSOKButton)
                return;
            
            CMRHistogramWindowController *controller = [[[CMRHistogramWindowController alloc] initWithVolumeWindow:volumeWindow] autorelease];
            [controller showWindow:self];
        }];
        
        return NO;
    }
    return YES;
}


+ (CMRSegTools*)sharedInstance
{
    return CMRSegToolsSharedInstance;
}

- (void)setAnnotationHidden:(BOOL)annotationHidden
{
    if (annotationHidden != _annotationHidden) {
        _annotationHidden = annotationHidden;
        
        NSArray *viewers = [ViewerController getDisplayed2DViewers];
        for( ViewerController *v in viewers)
        {
            DCMView *dcmView = [v imageView];
            if (annotationHidden) {
                dcmView.annotationType = annotNone;
            } else {
                
                dcmView.annotationType = [[NSUserDefaults standardUserDefaults] integerForKey: @"ANNOTATIONS"];
            
            }
            [dcmView setNeedsDisplay:YES];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:CRMSegToolsDidChangeAnnotationHiddenNotification object:self];
    }
}

- (void)_roisDidUpdateNotification:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:OSIROIManagerROIsDidUpdateNotification]) {
        // ignore the notification if it does not involve an ROI we care about
        BOOL foundReasonToUpdate = NO;
        NSMutableArray *allUpdatedROIS = [NSMutableArray array];
        
        [allUpdatedROIS addObjectsFromArray:[[notification userInfo] objectForKey:OSIROIUpdatedROIKey]];
        [allUpdatedROIS addObjectsFromArray:[[notification userInfo] objectForKey:OSIROIRemovedROIKey]];
        [allUpdatedROIS addObjectsFromArray:[[notification userInfo] objectForKey:OSIROIAddedROIKey]];
        
        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: Epicardium"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }
        
        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: Endocardium"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }
        
        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: LV/RV"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }
        
        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: Remote_stddev_"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }
        
        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: FWHMRegion"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }
        
        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: FWHM3D"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }
        
        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: Include in Infarct"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }

        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: Exclude from Infarct"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }
        
        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: No-reflow"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }
        
        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: Infarct Start Angle"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }
        
        if (foundReasonToUpdate == NO && [allUpdatedROIS indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){ return [[(OSIROI *)obj name] hasPrefix:@"CMRSegTools: Infarct End Angle"];}] != NSNotFound) {
            foundReasonToUpdate = YES;
        }
        
        if (foundReasonToUpdate == NO) {
            return;
        }
    }
    
    NSMutableArray *volumeWindows = [NSMutableArray array];
    id notificationObject = [notification object];
    if ([notificationObject isKindOfClass:[DCMView class]]) {
        DCMView *dcmView = (DCMView *)notificationObject;
        if ([[dcmView windowController] isKindOfClass:[ViewerController class]]) {
            OSIVolumeWindow *dcmVolumeWindow = [[OSIEnvironment sharedEnvironment] volumeWindowForViewerController:[dcmView windowController]];
            if (dcmVolumeWindow) {
                [volumeWindows addObject:dcmVolumeWindow];
            }
        }
    } else if ([notificationObject isKindOfClass:[OSIROIManager class]]) {
        OSIVolumeWindow *roiManagerVolumeWindow = [(OSIROIManager*) [notification object] volumeWindow];
        if (roiManagerVolumeWindow) {
            [volumeWindows addObject:roiManagerVolumeWindow];
        }
    } else {
        [volumeWindows addObjectsFromArray:[[OSIEnvironment sharedEnvironment] openVolumeWindows]];
    }
    
    for (OSIVolumeWindow *volumeWindow in volumeWindows) {
        NSInteger movieIndex = [[volumeWindow viewerController] curMovieIndex];
        NSInteger pixIndex = [[[volumeWindow viewerController] imageView] curImage];

        [self _updateCMRForVolumeWindow:volumeWindow movieIndex:movieIndex pixIndex:pixIndex];
        [[NSNotificationCenter defaultCenter] postNotificationName:CMRSegToolsROIsDidUpdateNotification object:self userInfo:@{@"volumeWindow": volumeWindow}];
    }
}

- (void)updateCMRForVolumeWindow:(OSIVolumeWindow *)volumeWindow //update everything in this volume window
{
    NSInteger movieIndex;
    NSInteger pixIndex;
    
    for (movieIndex = 0; movieIndex < [[volumeWindow viewerController] maxMovieIndex]; movieIndex++) {
        DCMView *dcmView = [[[volumeWindow viewerController] imageViews] objectAtIndex:movieIndex];
        for (pixIndex = 0; pixIndex < [[dcmView dcmPixList] count]; pixIndex++) {
            [self _updateCMRForVolumeWindow:(OSIVolumeWindow*)volumeWindow movieIndex:movieIndex pixIndex:pixIndex];
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:CMRSegToolsROIsDidUpdateNotification object:self userInfo:@{@"volumeWindow": volumeWindow}];
}

- (void)updateCMRForVolumeWindow:(OSIVolumeWindow*)volumeWindow movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex // update for this specific pix
{
    [self _updateCMRForVolumeWindow:volumeWindow movieIndex:movieIndex pixIndex:pixIndex];
    [[NSNotificationCenter defaultCenter] postNotificationName:CMRSegToolsROIsDidUpdateNotification object:self userInfo:@{@"volumeWindow": volumeWindow}];
}

- (void)_updateCMRForVolumeWindow:(OSIVolumeWindow*)volumeWindow movieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex // update for this specific pix
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"CMR42EmulationMode": @NO}];
    BOOL CMR42EmulationMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"CMR42EmulationMode"];
    
    OSIROIManager *roiManager = [volumeWindow ROIManager];
    OSIFloatVolumeData *normalFloatVolumeData = [volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    OSIFloatVolumeData *floatVolumeData = normalFloatVolumeData;
    if (CMR42EmulationMode) {
        floatVolumeData = [[[CMRHiResFloatVolumeData alloc] initWithFloatVolumeData:floatVolumeData widthSubdivisions:4 heightSubdivisions:4 depthSubdivisions:1] autorelease];
    }
    
    OSIROI *oldMyocardiumROI = [roiManager CMRFirstROIWithName:@"myocardium" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldMyocardiumROI) {
        [roiManager removeROI:oldMyocardiumROI];
    }
    
    OSIROI *oldWedgeClippedMyocardiumROI = [roiManager CMRFirstROIWithName:@"wedgeClippedMyocardium" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldWedgeClippedMyocardiumROI) {
        [roiManager removeROI:oldWedgeClippedMyocardiumROI];
    }

    OSIROI *oldSegementedROI = [roiManager CMRFirstROIWithName:@"segmented" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldSegementedROI) {
        [roiManager removeROI:oldSegementedROI];
    }
    
    OSIROI *oldNonWedgeClippedSegementedROI = [roiManager CMRFirstROIWithName:@"nonWedgeClippedSegmented" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldNonWedgeClippedSegementedROI) {
        [roiManager removeROI:oldNonWedgeClippedSegementedROI];
    }
    
    OSIROI *oldNoReflowROI = [roiManager CMRFirstROIWithName:@"no-reflow" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldNoReflowROI) {
        [roiManager removeROI:oldNoReflowROI];
    }
    
    OSIROI *oldremoteIntersectdROI = [roiManager CMRFirstROIWithName:@"remoteIntersectROI" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldremoteIntersectdROI) {
        [roiManager removeROI:oldremoteIntersectdROI];
    }
    
    OSIROI *oldregionIntersectdROI = [roiManager CMRFirstROIWithName:@"regionIntersectROI" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldregionIntersectdROI) {
        [roiManager removeROI:oldregionIntersectdROI];
    }
    
    OSIROI *oldregionIntersectdROI3D = [roiManager CMRFirstROIWithName:@"regionIntersectROI3D" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldregionIntersectdROI3D) {
        [roiManager removeROI:oldregionIntersectdROI3D];
    }
    
    OSIROI *oldMyocardiumSegement1ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 1" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldMyocardiumSegement1ROI) {
        [roiManager removeROI:oldMyocardiumSegement1ROI];
    }
    
    OSIROI *oldMyocardiumSegement2ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 2" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldMyocardiumSegement2ROI) {
        [roiManager removeROI:oldMyocardiumSegement2ROI];
    }
    
    OSIROI *oldMyocardiumSegement3ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 3" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldMyocardiumSegement3ROI) {
        [roiManager removeROI:oldMyocardiumSegement3ROI];
    }
    
    OSIROI *oldMyocardiumSegement4ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 4" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldMyocardiumSegement4ROI) {
        [roiManager removeROI:oldMyocardiumSegement4ROI];
    }
    
    OSIROI *oldMyocardiumSegement5ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 5" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldMyocardiumSegement5ROI) {
        [roiManager removeROI:oldMyocardiumSegement5ROI];
    }
    
    OSIROI *oldMyocardiumSegement6ROI = [roiManager CMRFirstROIWithName:@"myocardium segment 6" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldMyocardiumSegement6ROI) {
        [roiManager removeROI:oldMyocardiumSegement6ROI];
    }
    
    OSIROI *oldSegement1ROI = [roiManager CMRFirstROIWithName:@"segment 1" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldSegement1ROI) {
        [roiManager removeROI:oldSegement1ROI];
    }
    
    OSIROI *oldSegement1LabelROI = [roiManager CMRFirstROIWithName:@"myocardium segment 1 label" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldSegement1LabelROI) {
        [roiManager removeROI:oldSegement1LabelROI];
    }
    
    OSIROI *oldSegement2LabelROI = [roiManager CMRFirstROIWithName:@"myocardium segment 2 label" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldSegement2LabelROI) {
        [roiManager removeROI:oldSegement2LabelROI];
    }
    
    OSIROI *oldSegement3LabelROI = [roiManager CMRFirstROIWithName:@"myocardium segment 3 label" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldSegement3LabelROI) {
        [roiManager removeROI:oldSegement3LabelROI];
    }
    
    OSIROI *oldSegement4LabelROI = [roiManager CMRFirstROIWithName:@"myocardium segment 4 label" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldSegement4LabelROI) {
        [roiManager removeROI:oldSegement4LabelROI];
    }
    
    OSIROI *oldSegement5LabelROI = [roiManager CMRFirstROIWithName:@"myocardium segment 5 label" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldSegement5LabelROI) {
        [roiManager removeROI:oldSegement5LabelROI];
    }
    
    OSIROI *oldSegement6LabelROI = [roiManager CMRFirstROIWithName:@"myocardium segment 6 label" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldSegement6LabelROI) {
        [roiManager removeROI:oldSegement6LabelROI];
    }
    
    OSIROI *oldCLippedEndocardiumROI = [roiManager CMRFirstROIWithName:@"clipped endocardium" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldCLippedEndocardiumROI) {
        [roiManager removeROI:oldCLippedEndocardiumROI];
    }
    
    OSIROI *oldCLippedEpicardiumROI = [roiManager CMRFirstROIWithName:@"clipped epicardium" movieIndex:movieIndex pixIndex:pixIndex];
    if (oldCLippedEpicardiumROI) {
        [roiManager removeROI:oldCLippedEpicardiumROI];
    }
    

    OSIROI *outsideROI = [roiManager epicardialROIAtMovieIndex:movieIndex pixIndex:pixIndex];
    OSIROI *insideROI = [roiManager endocardialROIAtMovieIndex:movieIndex pixIndex:pixIndex];
    if (outsideROI && insideROI) {
        OSIROIMask *outsideMask = [outsideROI ROIMaskForFloatVolumeData:floatVolumeData];
        OSIROIMask *insideMask = [insideROI ROIMaskForFloatVolumeData:floatVolumeData];
        
        OSIROIMask *normalOutsideMask = [outsideROI ROIMaskForFloatVolumeData:normalFloatVolumeData]; // normal because if CMR42 emulation mode the others are wonky hi res versions
        OSIROIMask *normalInsideMask = [insideROI ROIMaskForFloatVolumeData:normalFloatVolumeData];
        OSIROIMask *normalMyocardiumMask = [normalOutsideMask ROIMaskBySubtractingMask:normalInsideMask];
        
        OSIROIMask *myocardiumMask = [outsideMask ROIMaskBySubtractingMask:insideMask];
        OSIMaskROI *myocardiumROI = [[[OSIMaskROI alloc] initWithROIMask:myocardiumMask homeFloatVolumeData:floatVolumeData name:@"myocardium"] autorelease];
        if ([myocardiumMask maskRunCount]) {
            [roiManager addROI:myocardiumROI];
        }
        
        OSIROI* myocardium3D = [roiManager firstVisibleROIWithNamePrefix:@"myocardium3D"];
        if (myocardium3D) {
            OSIROIMask *myocardium3DMask = [myocardium3D ROIMaskForFloatVolumeData:floatVolumeData];
            myocardium3DMask = [myocardium3DMask ROIMaskByUnioningWithMask:myocardiumMask];
            OSIMaskROI *myocardium3DROI = [[[OSIMaskROI alloc] initWithROIMask:myocardium3DMask homeFloatVolumeData:floatVolumeData name:@"myocardium3D"] autorelease];
            [roiManager removeROI:myocardium3D];
            [roiManager addROI:myocardium3DROI];
        }
        else
        {
            OSIMaskROI *myocardium3DROI = [[[OSIMaskROI alloc] initWithROIMask:myocardiumMask homeFloatVolumeData:floatVolumeData name:@"myocardium3D"] autorelease];
            [roiManager addROI:myocardium3DROI];
        }
        
        OSIROI *LVRVROI = [roiManager CMRFirstROIWithNamePrefix:@"CMRSegTools: LV/RV" movieIndex:movieIndex pixIndex:pixIndex];
        if (LVRVROI && [[LVRVROI bezierPath] elementCount] == 2) {
            OSISlab slab;
            N3AffineTransform rotationTransform;
            
            // find how many sections we are going to draw
            BOOL draw6Sections = YES;
            NSArray *LVRVNameComponents = [[LVRVROI name] componentsSeparatedByString:@";"];
            for (NSString *component in LVRVNameComponents) {
                if ([component hasPrefix:@"Number_of_sections_"]) {
                    NSInteger sectionCount = [[component substringFromIndex:[@"Number_of_sections_" length]] integerValue];
                    if (sectionCount == 4) {
                        draw6Sections = NO;
                    }
                }
            }
            
            slab.thickness = 8; // bs make this a real value!
            slab.plane.normal = N3VectorApplyTransformToDirectionalVector(N3VectorMake(0, 0, 1), N3AffineTransformInvert(floatVolumeData.volumeTransform));
            
            N3Vector centerVector = N3VectorZero;
            [[LVRVROI bezierPath] elementAtIndex:0 control1:NULL control2:NULL endpoint:&centerVector];
            N3Vector endVector = N3VectorZero;
            [[LVRVROI bezierPath] elementAtIndex:1 control1:NULL control2:NULL endpoint:&endVector];
            endVector = N3VectorAdd(centerVector, N3VectorScalarMultiply(N3VectorSubtract(endVector, centerVector), 3));
            slab.plane.point = centerVector;
            
            rotationTransform = N3AffineTransformMakeTranslationWithVector(centerVector);
            if (draw6Sections) {
                rotationTransform = N3AffineTransformRotateAroundVector(rotationTransform, -M_PI / 3, slab.plane.normal);
            } else {
                rotationTransform = N3AffineTransformRotateAroundVector(rotationTransform, -M_PI / 2, slab.plane.normal);
            }
            rotationTransform = N3AffineTransformTranslate(rotationTransform, -centerVector.x, -centerVector.y, -centerVector.z);
            
            N3Vector secondEndVector = endVector;
            endVector = N3VectorApplyTransform(endVector, N3AffineTransformInvert(rotationTransform));
            
            N3Vector labelVector = N3VectorLerp(centerVector, N3VectorLerp(endVector, secondEndVector, .5), .35);
            
            N3MutableBezierPath *segmentPath = [N3MutableBezierPath bezierPath];
            [segmentPath moveToVector:centerVector];
            [segmentPath lineToVector:endVector];
            [segmentPath lineToVector:secondEndVector];
            [segmentPath close];
            
            OSIPathExtrusionROI *segment1ROI = [[[OSIPathExtrusionROI alloc] initWith:segmentPath slab:slab homeFloatVolumeData:floatVolumeData name:@"segment 1"] autorelease];
            OSIROIMask *segment1ROIMask = [segment1ROI ROIMaskForFloatVolumeData:floatVolumeData];
            OSIROIMask *myocardiumSegment1Mask = [segment1ROIMask ROIMaskByIntersectingWithMask:myocardiumMask];
            OSIMaskROI *myocardiumSegement1ROI = [[[OSIMaskROI alloc] initWithROIMask:myocardiumSegment1Mask homeFloatVolumeData:floatVolumeData name:@"myocardium segment 1"] autorelease];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMRShowSegements"]) {
                [myocardiumSegement1ROI setFillColor:[[NSColor whiteColor] colorWithAlphaComponent:.1]];
                NSString *label = [NSString stringWithFormat:@"1: %0.f", [[myocardiumSegement1ROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData] intensityMean]];
                CMRTextROI *segment1LabelROI = [[[CMRTextROI alloc] initWithText:label position:labelVector homeFloatVolumeData:floatVolumeData name:@"myocardium segment 1 label"] autorelease];
                [roiManager addROI:segment1LabelROI];
            }
            if ([myocardiumSegment1Mask maskRunCount]) {
                [roiManager addROI:myocardiumSegement1ROI];
            }
            
            // segment 2
            endVector = secondEndVector;
            secondEndVector = N3VectorApplyTransform(endVector, rotationTransform);
            labelVector = N3VectorApplyTransform(labelVector, rotationTransform);
            
            segmentPath = [N3MutableBezierPath bezierPath];
            [segmentPath moveToVector:centerVector];
            [segmentPath lineToVector:endVector];
            [segmentPath lineToVector:secondEndVector];
            [segmentPath close];
            
            OSIPathExtrusionROI *segment2ROI = [[[OSIPathExtrusionROI alloc] initWith:segmentPath slab:slab homeFloatVolumeData:floatVolumeData name:@"segment 2"] autorelease];
            OSIROIMask *segment2ROIMask = [segment2ROI ROIMaskForFloatVolumeData:floatVolumeData];
            OSIROIMask *myocardiumSegment2Mask = [segment2ROIMask ROIMaskByIntersectingWithMask:myocardiumMask];
            OSIMaskROI *myocardiumSegement2ROI = [[[OSIMaskROI alloc] initWithROIMask:myocardiumSegment2Mask homeFloatVolumeData:floatVolumeData name:@"myocardium segment 2"] autorelease];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMRShowSegements"]) {
                [myocardiumSegement2ROI setFillColor:[[NSColor blackColor] colorWithAlphaComponent:.1]];
                NSString *label = [NSString stringWithFormat:@"2: %0.f", [[myocardiumSegement2ROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData] intensityMean]];
                CMRTextROI *segment2LabelROI = [[[CMRTextROI alloc] initWithText:label position:labelVector homeFloatVolumeData:floatVolumeData name:@"myocardium segment 2 label"] autorelease];
                [roiManager addROI:segment2LabelROI];
            }
            if ([myocardiumSegment2Mask maskRunCount]) {
                [roiManager addROI:myocardiumSegement2ROI];
            }
            
            // segment 3
            endVector = secondEndVector;
            secondEndVector = N3VectorApplyTransform(endVector, rotationTransform);
            labelVector = N3VectorApplyTransform(labelVector, rotationTransform);
            
            segmentPath = [N3MutableBezierPath bezierPath];
            [segmentPath moveToVector:centerVector];
            [segmentPath lineToVector:endVector];
            [segmentPath lineToVector:secondEndVector];
            [segmentPath close];
            
            OSIPathExtrusionROI *segment3ROI = [[[OSIPathExtrusionROI alloc] initWith:segmentPath slab:slab homeFloatVolumeData:floatVolumeData name:@"segment 3"] autorelease];
            OSIROIMask *segment3ROIMask = [segment3ROI ROIMaskForFloatVolumeData:floatVolumeData];
            OSIROIMask *myocardiumSegment3Mask = [segment3ROIMask ROIMaskByIntersectingWithMask:myocardiumMask];
            OSIMaskROI *myocardiumSegement3ROI = [[[OSIMaskROI alloc] initWithROIMask:myocardiumSegment3Mask homeFloatVolumeData:floatVolumeData name:@"myocardium segment 3"] autorelease];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMRShowSegements"]) {
                [myocardiumSegement3ROI setFillColor:[[NSColor whiteColor] colorWithAlphaComponent:.1]];
                NSString *label = [NSString stringWithFormat:@"3: %0.f", [[myocardiumSegement3ROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData] intensityMean]];
                CMRTextROI *segment3LabelROI = [[[CMRTextROI alloc] initWithText:label position:labelVector homeFloatVolumeData:floatVolumeData name:@"myocardium segment 3 label"] autorelease];
                [roiManager addROI:segment3LabelROI];
            }
            if ([myocardiumSegment3Mask maskRunCount]) {
                [roiManager addROI:myocardiumSegement3ROI];
            }
            // segment 4
            endVector = secondEndVector;
            secondEndVector = N3VectorApplyTransform(endVector, rotationTransform);
            labelVector = N3VectorApplyTransform(labelVector, rotationTransform);
            
            segmentPath = [N3MutableBezierPath bezierPath];
            [segmentPath moveToVector:centerVector];
            [segmentPath lineToVector:endVector];
            [segmentPath lineToVector:secondEndVector];
            [segmentPath close];
            
            OSIPathExtrusionROI *segment4ROI = [[[OSIPathExtrusionROI alloc] initWith:segmentPath slab:slab homeFloatVolumeData:floatVolumeData name:@"segment 4"] autorelease];
            OSIROIMask *segment4ROIMask = [segment4ROI ROIMaskForFloatVolumeData:floatVolumeData];
            OSIROIMask *myocardiumSegment4Mask = [segment4ROIMask ROIMaskByIntersectingWithMask:myocardiumMask];
            OSIMaskROI *myocardiumSegement4ROI = [[[OSIMaskROI alloc] initWithROIMask:myocardiumSegment4Mask homeFloatVolumeData:floatVolumeData name:@"myocardium segment 4"] autorelease];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMRShowSegements"]) {
                [myocardiumSegement4ROI setFillColor:[[NSColor blackColor] colorWithAlphaComponent:.1]];
                NSString *label = [NSString stringWithFormat:@"4: %0.f", [[myocardiumSegement4ROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData] intensityMean]];
                CMRTextROI *segment4LabelROI = [[[CMRTextROI alloc] initWithText:label position:labelVector homeFloatVolumeData:floatVolumeData name:@"myocardium segment 4 label"] autorelease];
                [roiManager addROI:segment4LabelROI];
            }
            if ([myocardiumSegment4Mask maskRunCount]) {
                [roiManager addROI:myocardiumSegement4ROI];
            }
            if (draw6Sections) {
                // segment 5
                endVector = secondEndVector;
                secondEndVector = N3VectorApplyTransform(endVector, rotationTransform);
                labelVector = N3VectorApplyTransform(labelVector, rotationTransform);
                
                segmentPath = [N3MutableBezierPath bezierPath];
                [segmentPath moveToVector:centerVector];
                [segmentPath lineToVector:endVector];
                [segmentPath lineToVector:secondEndVector];
                [segmentPath close];
                
                OSIPathExtrusionROI *segment5ROI = [[[OSIPathExtrusionROI alloc] initWith:segmentPath slab:slab homeFloatVolumeData:floatVolumeData name:@"segment 5"] autorelease];
                OSIROIMask *segment5ROIMask = [segment5ROI ROIMaskForFloatVolumeData:floatVolumeData];
                OSIROIMask *myocardiumSegment5Mask = [segment5ROIMask ROIMaskByIntersectingWithMask:myocardiumMask];
                OSIMaskROI *myocardiumSegement5ROI = [[[OSIMaskROI alloc] initWithROIMask:myocardiumSegment5Mask homeFloatVolumeData:floatVolumeData name:@"myocardium segment 5"] autorelease];
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMRShowSegements"]) {
                    [myocardiumSegement5ROI setFillColor:[[NSColor whiteColor] colorWithAlphaComponent:.1]];
                    NSString *label = [NSString stringWithFormat:@"5: %0.f", [[myocardiumSegement5ROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData] intensityMean]];
                    CMRTextROI *segment5LabelROI = [[[CMRTextROI alloc] initWithText:label position:labelVector homeFloatVolumeData:floatVolumeData name:@"myocardium segment 5 label"] autorelease];
                    [roiManager addROI:segment5LabelROI];
                }
                if ([myocardiumSegment5Mask maskRunCount]) {
                    [roiManager addROI:myocardiumSegement5ROI];
                }
                
                // segment 6
                endVector = secondEndVector;
                secondEndVector = N3VectorApplyTransform(endVector, rotationTransform);
                labelVector = N3VectorApplyTransform(labelVector, rotationTransform);
                
                segmentPath = [N3MutableBezierPath bezierPath];
                [segmentPath moveToVector:centerVector];
                [segmentPath lineToVector:endVector];
                [segmentPath lineToVector:secondEndVector];
                [segmentPath close];
                
                OSIPathExtrusionROI *segment6ROI = [[[OSIPathExtrusionROI alloc] initWith:segmentPath slab:slab homeFloatVolumeData:floatVolumeData name:@"segment 6"] autorelease];
                OSIROIMask *segment6ROIMask = [segment6ROI ROIMaskForFloatVolumeData:floatVolumeData];
                OSIROIMask *myocardiumSegment6Mask = [segment6ROIMask ROIMaskByIntersectingWithMask:myocardiumMask];
                OSIMaskROI *myocardiumSegement6ROI = [[[OSIMaskROI alloc] initWithROIMask:myocardiumSegment6Mask homeFloatVolumeData:floatVolumeData name:@"myocardium segment 6"] autorelease];
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMRShowSegements"]) {
                    [myocardiumSegement6ROI setFillColor:[[NSColor blackColor] colorWithAlphaComponent:.1]];
                    NSString *label = [NSString stringWithFormat:@"6: %0.f", [[myocardiumSegement6ROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData] intensityMean]];
                    CMRTextROI *segment6LabelROI = [[[CMRTextROI alloc] initWithText:label position:labelVector homeFloatVolumeData:floatVolumeData name:@"myocardium segment 6 label"] autorelease];
                    [roiManager addROI:segment6LabelROI];
                }
                if ([myocardiumSegment6Mask maskRunCount]) {
                    [roiManager addROI:myocardiumSegement6ROI];
                }
            }
        }
        
        // build the angle tool ROIs
        OSIROI *infactStartAngleROI = [roiManager CMRFirstROIWithNamePrefix:@"CMRSegTools: Infarct Start Angle" movieIndex:movieIndex pixIndex:pixIndex];
        OSIROI *infactEndAngleROI = [roiManager CMRFirstROIWithNamePrefix:@"CMRSegTools: Infarct End Angle" movieIndex:movieIndex pixIndex:pixIndex];
        
        N3BezierPath *infarctAngleWedge = nil;
        BOOL infarctWedgeIsHealthy = NO;
        OSISlab wedgeSlab;
        
        if (infactStartAngleROI && infactEndAngleROI && [insideROI bezierPath] && [outsideROI bezierPath]) {
            // find planes the coorespond to the start and end ROIs
            N3Vector normalVector = N3VectorApplyTransformToDirectionalVector(N3VectorMake(0, 0, 1), N3AffineTransformInvert(floatVolumeData.volumeTransform));
            N3Vector startVector0 = N3VectorZero;
            N3Vector startVector1 = N3VectorZero;
            N3Vector endVector0 = N3VectorZero;
            N3Vector endVector1 = N3VectorZero;
            
            [[infactStartAngleROI bezierPath] elementAtIndex:0 control1:NULL control2:NULL endpoint:&startVector0];
            [[infactStartAngleROI bezierPath] elementAtIndex:1 control1:NULL control2:NULL endpoint:&startVector1];
            N3Plane startPlane = N3PlaneMake(startVector0, N3VectorCrossProduct(N3VectorSubtract(startVector1, startVector0), normalVector));
            
            [[infactEndAngleROI bezierPath] elementAtIndex:0 control1:NULL control2:NULL endpoint:&endVector0];
            [[infactEndAngleROI bezierPath] elementAtIndex:1 control1:NULL control2:NULL endpoint:&endVector1];
            N3Plane endPlane = N3PlaneMake(endVector0, N3VectorCrossProduct(N3VectorSubtract(endVector1, endVector0), normalVector));
            
            NSArray *relativePositionsStart;
            NSArray *relativePositionsEnd;
            NSArray *intersectionsStart;
            NSArray *intersectionsEnd;
            NSUInteger i;
            CGFloat insideRelativePositionStart = CGFLOAT_MAX;
            CGFloat insideRelativePositionEnd = CGFLOAT_MAX;
            CGFloat outsideRelativePositionStart = CGFLOAT_MAX;
            CGFloat outsideRelativePositionEnd = CGFLOAT_MAX;
            CGFloat projection;
            N3Vector intersection;
            CGFloat closestRelativePosition;
            CGFloat distance;
            CGFloat closestVectorDistance;
            N3BezierPath *insideROIBezierPath = [[insideROI bezierPath] counterClockwiseBezierPathWithNormal:N3VectorInvert(normalVector)];
            N3BezierPath *outsideROIBezierPath = [[outsideROI bezierPath] counterClockwiseBezierPathWithNormal:N3VectorInvert(normalVector)];
            
            intersectionsStart = [insideROIBezierPath intersectionsWithPlane:startPlane relativePositions:&relativePositionsStart];
            intersectionsEnd = [insideROIBezierPath intersectionsWithPlane:endPlane relativePositions:&relativePositionsEnd];
            
            if ([intersectionsStart count] && [intersectionsEnd count]) {
                // is the entersection between the start and end of the infarct angle roi
                closestVectorDistance = CGFLOAT_MAX;
                closestRelativePosition = CGFLOAT_MAX;
                for (i = 0; i < [intersectionsStart count]; i++) {
                    intersection = [[intersectionsStart objectAtIndex:i] N3VectorValue];
                    projection = N3VectorDotProduct(N3VectorNormalize(N3VectorSubtract(startVector1, startVector0)), N3VectorSubtract(intersection, startVector0));
                    if (projection >= 0 && projection <= N3VectorLength(N3VectorSubtract(startVector1, startVector0))) {
                        distance = N3VectorDistance(startVector0, intersection);
                        if (distance < closestVectorDistance) {
                            closestRelativePosition = [[relativePositionsStart objectAtIndex:i] doubleValue];
                            closestVectorDistance = distance;
                        }
                    }
                }
                insideRelativePositionStart = closestRelativePosition;
                
                closestVectorDistance = CGFLOAT_MAX;
                closestRelativePosition = CGFLOAT_MAX;
                for (i = 0; i < [intersectionsEnd count]; i++) {
                    intersection = [[intersectionsEnd objectAtIndex:i] N3VectorValue];
                    projection = N3VectorDotProduct(N3VectorNormalize(N3VectorSubtract(endVector1, endVector0)), N3VectorSubtract(intersection, endVector0));
                    if (projection >= 0 && projection <= N3VectorLength(N3VectorSubtract(endVector1, endVector0))) {
                        distance = N3VectorDistance(endVector0, intersection);
                        if (distance < closestVectorDistance) {
                            closestRelativePosition = [[relativePositionsEnd objectAtIndex:i] doubleValue];
                            closestVectorDistance = distance;
                        }
                    }
                }
                insideRelativePositionEnd = closestRelativePosition;
            }
            
            intersectionsStart = [outsideROIBezierPath intersectionsWithPlane:startPlane relativePositions:&relativePositionsStart];
            intersectionsEnd = [outsideROIBezierPath intersectionsWithPlane:endPlane relativePositions:&relativePositionsEnd];
            
            if ([intersectionsStart count] && [intersectionsEnd count]) {
                // is the intersection between the start and end of the infarct angle roi
                closestVectorDistance = CGFLOAT_MAX;
                closestRelativePosition = CGFLOAT_MAX;
                for (i = 0; i < [intersectionsStart count]; i++) {
                    intersection = [[intersectionsStart objectAtIndex:i] N3VectorValue];
                    projection = N3VectorDotProduct(N3VectorNormalize(N3VectorSubtract(startVector1, startVector0)), N3VectorSubtract(intersection, startVector0));
                    if (projection >= 0 && projection <= N3VectorLength(N3VectorSubtract(startVector1, startVector0))) {
                        distance = N3VectorDistance(startVector0, intersection);
                        if (distance < closestVectorDistance) {
                            closestRelativePosition = [[relativePositionsStart objectAtIndex:i] doubleValue];
                            closestVectorDistance = distance;
                        }
                    }
                }
                outsideRelativePositionStart = closestRelativePosition;
                
                closestVectorDistance = CGFLOAT_MAX;
                closestRelativePosition = CGFLOAT_MAX;
                for (i = 0; i < [intersectionsEnd count]; i++) {
                    intersection = [[intersectionsEnd objectAtIndex:i] N3VectorValue];
                    projection = N3VectorDotProduct(N3VectorNormalize(N3VectorSubtract(endVector1, endVector0)), N3VectorSubtract(intersection, endVector0));
                    if (projection >= 0 && projection <= N3VectorLength(N3VectorSubtract(endVector1, endVector0))) {
                        distance = N3VectorDistance(endVector0, intersection);
                        if (distance < closestVectorDistance) {
                            closestRelativePosition = [[relativePositionsEnd objectAtIndex:i] doubleValue];
                            closestVectorDistance = distance;
                        }
                    }
                }
                outsideRelativePositionEnd = closestRelativePosition;
            }
            
            if (insideRelativePositionStart != CGFLOAT_MAX && insideRelativePositionEnd != CGFLOAT_MAX &&
                outsideRelativePositionStart != CGFLOAT_MAX && outsideRelativePositionEnd != CGFLOAT_MAX) {
                wedgeSlab = OSISlabMake(N3PlaneMake(startVector1, normalVector), 4);
                N3BezierPath *clippedPath;
                
                clippedPath = [insideROIBezierPath bezierPathByClippingFromRelativePosition:insideRelativePositionStart toRelativePotions:insideRelativePositionEnd];
                OSIPathExtrusionROI *clippedEndocardium = [[[OSIPathExtrusionROI alloc] initWith:clippedPath slab:wedgeSlab homeFloatVolumeData:floatVolumeData name:@"clipped endocardium"] autorelease];
                NSColor *endcardiumColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMREndocardiumColor"]];
                endcardiumColor = [endcardiumColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
                [clippedEndocardium setStrokeColor:[NSColor colorWithCalibratedRed:0.5*[endcardiumColor redComponent] green:0.5*[endcardiumColor greenComponent] blue:0.5*[endcardiumColor blueComponent] alpha:1]];
                [clippedEndocardium setStrokeThickness:3];
                [roiManager addROI:clippedEndocardium];
                
                clippedPath = [outsideROIBezierPath bezierPathByClippingFromRelativePosition:outsideRelativePositionStart toRelativePotions:outsideRelativePositionEnd];
                OSIPathExtrusionROI *clippedEpicardium = [[[OSIPathExtrusionROI alloc] initWith:clippedPath slab:wedgeSlab homeFloatVolumeData:floatVolumeData name:@"clipped epicardium"] autorelease];
                NSColor *epicardiumColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMREpicardiumColor"]];
                epicardiumColor = [epicardiumColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
                [clippedEpicardium setStrokeColor:[NSColor colorWithCalibratedRed:0.5*[epicardiumColor redComponent] green:0.5*[epicardiumColor greenComponent] blue:0.5*[epicardiumColor blueComponent] alpha:1]];
                [clippedEpicardium setStrokeThickness:3];
                [roiManager addROI:clippedEpicardium];
                
                N3MutableBezierPath *wedge = [N3MutableBezierPath bezierPath];
                [wedge moveToVector:N3VectorAdd(startVector1, N3VectorScalarMultiply(N3VectorSubtract(startVector1, startVector0), .5))];
                [wedge lineToVector:startVector0];
                [wedge lineToVector:endVector0];
                [wedge lineToVector:N3VectorAdd(endVector1, N3VectorScalarMultiply(N3VectorSubtract(endVector1, endVector0), .5))];
                
                /* test the line drawing code */
                
//                N3Vector startMaskVector0 = N3VectorApplyTransform(startVector0, floatVolumeData.volumeTransform);
//                N3Vector endMaskVector0 = N3VectorApplyTransform(startVector1, floatVolumeData.volumeTransform);
//                N3Vector startMaskVector1 = N3VectorApplyTransform(endVector0, floatVolumeData.volumeTransform);
//                N3Vector endMaskVector1 = N3VectorApplyTransform(endVector1, floatVolumeData.volumeTransform);
//                
//                startMaskVector0.x -= 0.5;
//                endMaskVector0.x -= 0.5;
//                startMaskVector1.x -= 0.5;
//                endMaskVector1.x -= 0.5;
//                
//                startMaskVector0.y -= 0.5;
//                endMaskVector0.y -= 0.5;
//                startMaskVector1.y -= 0.5;
//                endMaskVector1.y -= 0.5;
//                
//                NSArray *line0Indexes = [CMRHistogramWindowController _maskIndexPointsOnLineFrom:startMaskVector0 to:endMaskVector0];
//                OSIROIMask *line0Mask = [[[OSIROIMask alloc] initWithIndexes:line0Indexes] autorelease];
//                
//                NSArray *line1Indexes = [CMRHistogramWindowController _maskIndexPointsOnLineFrom:startMaskVector1 to:endMaskVector1];
//                OSIROIMask *line1Mask = [[[OSIROIMask alloc] initWithIndexes:line1Indexes] autorelease];
//                
//                OSIROI *oldLine0ROI = [roiManager CMRFirstROIWithName:@"line0ROI" movieIndex:movieIndex pixIndex:pixIndex];
//                if (oldLine0ROI) {
//                    [roiManager removeROI:oldLine0ROI];
//                }
//                OSIROI *oldLine1ROI = [roiManager CMRFirstROIWithName:@"line1ROI" movieIndex:movieIndex pixIndex:pixIndex];
//                if (oldLine1ROI) {
//                    [roiManager removeROI:oldLine1ROI];
//                }
//
//                if ([line0Mask maskRunCount]) {
//                    OSIMaskROI *line0ROI = [[[OSIMaskROI alloc] initWithROIMask:line0Mask homeFloatVolumeData:floatVolumeData name:@"line0ROI"] autorelease];
//                    [line0ROI setFillColor:[NSColor blueColor]];
//                    [roiManager addROI:line0ROI];
//                }
//                if ([line1Mask maskRunCount]) {
//                    OSIMaskROI *line1ROI = [[[OSIMaskROI alloc] initWithROIMask:line1Mask homeFloatVolumeData:floatVolumeData name:@"line1ROI"] autorelease];
//                    [line1ROI setFillColor:[NSColor blueColor]];
//                    [roiManager addROI:line1ROI];
//                }
                
                /* end the line drawing code */
                
                
                // this is kinda bogus, but I bet it will work, all we need is a polygon that covers the wedge
                N3Vector wayOutVector = N3VectorNormalize(N3VectorAdd(N3VectorNormalize(N3VectorSubtract(startVector1, startVector0)), N3VectorNormalize(N3VectorSubtract(endVector1, endVector0))));
                wayOutVector = N3VectorScalarMultiply(wayOutVector, N3VectorDistance(startVector1, startVector0) + N3VectorDistance(endVector1, endVector0));
                wayOutVector = N3VectorAdd(startVector0, wayOutVector);
                [wedge lineToVector:wayOutVector];
                
                [wedge close];
                infarctAngleWedge = wedge;
                
                if (N3VectorDotProduct(N3VectorCrossProduct(N3VectorSubtract(startVector1, startVector0), N3VectorSubtract(endVector1, endVector0)), normalVector) > 0) {
                    infarctWedgeIsHealthy = YES;
                } else {
                    infarctWedgeIsHealthy = NO;
                }
            }
        }
        
        // ok, so we have mycardium and segments, now we want to build up the infarct ROI
        
        // first build it up
        OSIROIMask *infarctMask = [[[OSIROIMask alloc] initWithMaskRuns:[NSArray array]] autorelease];
        
        // first use a remote ROI to add to the infarct
        OSIROI *remoteROI = [roiManager CMRFirstROIWithNamePrefix:@"CMRSegTools: Remote_stddev_" movieIndex:movieIndex pixIndex:pixIndex];
        if (remoteROI) {
            float standardDevs = [[[remoteROI name] substringFromIndex:[@"CMRSegTools: Remote_stddev_" length]] floatValue];
            
            OSIROIMask *remoteMask = [remoteROI ROIMaskForFloatVolumeData:normalFloatVolumeData];
            OSIROIMask *intersectedRemoteMask = [remoteMask ROIMaskByIntersectingWithMask:normalMyocardiumMask];
            if ([intersectedRemoteMask maskRunCount]) {
                OSIROIFloatPixelData *remotePixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:intersectedRemoteMask floatVolumeData:normalFloatVolumeData] autorelease];
                float remoteMean = [remotePixelData intensityMean];
                float remoteStdDev = [remotePixelData intensityStandardDeviation];
                
                NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"self.intensity > %f", remoteMean + standardDevs*remoteStdDev];
                OSIROIMask *remoteSegmentedMask = [normalMyocardiumMask filteredROIMaskUsingPredicate:searchPredicate floatVolumeData:normalFloatVolumeData];
                if (CMR42EmulationMode) {
                    N3Vector centerVector = N3VectorZero;
                    [[remoteROI bezierPath] elementAtIndex:0 control1:NULL control2:NULL endpoint:&centerVector];
                    
                    NSUInteger depth = round(N3VectorApplyTransform(centerVector, normalFloatVolumeData.volumeTransform).z);
                    
                    OSIROIMask *filledMask = [[[OSIROIMask alloc] initWithExtentWidth:normalFloatVolumeData.pixelsWide height:normalFloatVolumeData.pixelsHigh depth:1] autorelease];
                    filledMask = [filledMask ROIMaskByTranslatingByX:0 Y:0 Z:depth];
                    
                    searchPredicate = [NSPredicate predicateWithFormat:@"self.intensity >= %f", round(remoteMean + standardDevs*remoteStdDev)];
                    remoteSegmentedMask = [filledMask filteredROIMaskUsingPredicate:searchPredicate floatVolumeData:normalFloatVolumeData];
                    
                    remoteSegmentedMask = [remoteSegmentedMask ROIMaskWithWidthSubdivisions:4 heightSubdivisions:4 depthSubdivisions:1];
                    remoteSegmentedMask = [remoteSegmentedMask ROIMaskByIntersectingWithMask:myocardiumMask];
                }
                
                infarctMask = [infarctMask ROIMaskByUnioningWithMask:remoteSegmentedMask];
                
                OSIMaskROI *remoteIntersectROI = [[[OSIMaskROI alloc] initWithROIMask:intersectedRemoteMask homeFloatVolumeData:floatVolumeData name:@"remoteIntersectROI"] autorelease];
                NSColor *remoteColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]];
                CGFloat remoteOpacity = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRRemoteColorOpacity"];
                [remoteIntersectROI setFillColor:[remoteColor colorWithAlphaComponent:remoteOpacity]];
                if ([intersectedRemoteMask maskRunCount]) {
                    [roiManager addROI:remoteIntersectROI];
                }
            }
        }
        
        // Hsu method
        NSArray *epiNameComponents = [[outsideROI name] componentsSeparatedByString:@";"];
        for (NSString *component in epiNameComponents) {
            if ([component hasPrefix:@"HsuMean_"]) {
                OSIROI *ROIHsu = [roiManager CMRFirstROIWithName:@"Hsu" movieIndex:movieIndex pixIndex:pixIndex];
                if (ROIHsu) {
                    OSIROIMask *MaskHsu = [ROIHsu ROIMaskForFloatVolumeData:floatVolumeData];
                    MaskHsu = [MaskHsu ROIMaskByIntersectingWithMask:myocardiumMask];
                    infarctMask = [infarctMask ROIMaskByUnioningWithMask:MaskHsu];
                }
            }
        }
        
        int seg = 1;
        for (NSString *component in epiNameComponents) {
            if ([component hasPrefix:@"xSD_Segment_"]) {
                seg = [[component substringFromIndex:[@"xSD_Segment_" length]] integerValue];
            }
            if ([component hasPrefix:@"xSD_Remote_stddev_"]) {
                float standardDevs = [[component substringFromIndex:[@"xSD_Remote_stddev_" length]] floatValue];
                OSIROI *segmentROI = [roiManager CMRFirstVisibleROIWithName:[NSString stringWithFormat:@"myocardium segment %d",seg]];
                if (segmentROI) {
                    NSColor *remoteColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]];
                    CGFloat remoteOpacity = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRRemoteColorOpacity"];
                    [segmentROI setFillColor:[remoteColor colorWithAlphaComponent:remoteOpacity]];
                    OSIROIMask *segmentMask = [segmentROI ROIMaskForFloatVolumeData:[myocardiumROI homeFloatVolumeData]];
                    segmentMask = [segmentMask ROIMaskByIntersectingWithMask:normalMyocardiumMask];
                    OSIROIFloatPixelData *remotePixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:segmentMask floatVolumeData:normalFloatVolumeData] autorelease];
                    float remoteMean = [remotePixelData intensityMean];
                    float remoteStdDev = [remotePixelData intensityStandardDeviation];
                    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"self.intensity > %f", remoteMean + standardDevs*remoteStdDev];
                    OSIROIMask *remoteSegmentedMask = [normalMyocardiumMask filteredROIMaskUsingPredicate:searchPredicate floatVolumeData:normalFloatVolumeData];
                    infarctMask = [infarctMask ROIMaskByUnioningWithMask:remoteSegmentedMask];
                }
            }
            if ([component hasPrefix:@"FWHM_Segment_"]) {
                seg = [[component substringFromIndex:[@"FWHM_Segment_" length]] integerValue];
                OSIROI *segmentROI = [roiManager CMRFirstVisibleROIWithName:[NSString stringWithFormat:@"myocardium segment %d",seg]];
                if (segmentROI) {
                    NSColor *remoteColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]];
                    CGFloat remoteOpacity = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRRemoteColorOpacity"];
                    [segmentROI setFillColor:[remoteColor colorWithAlphaComponent:remoteOpacity]];
                    OSIROIMask *segmentMask = [segmentROI ROIMaskForFloatVolumeData:[myocardiumROI homeFloatVolumeData]];
                    segmentMask = [segmentMask ROIMaskByIntersectingWithMask:normalMyocardiumMask];
                    OSIROIFloatPixelData *remotePixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:segmentMask floatVolumeData:normalFloatVolumeData] autorelease];
                    OSIROIFloatPixelData *floatPixelData = [myocardiumROI ROIFloatPixelDataForFloatVolumeData:normalFloatVolumeData];
                    float regionMax = [floatPixelData intensityMax];
                    float remoteMean = [remotePixelData intensityMean];
                    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"self.intensity > %f", (remoteMean + regionMax)/2];
                    OSIROIMask *remoteSegmentedMask = [normalMyocardiumMask filteredROIMaskUsingPredicate:searchPredicate floatVolumeData:normalFloatVolumeData];
                    infarctMask = [infarctMask ROIMaskByUnioningWithMask:remoteSegmentedMask];
                }
            }
        }
                        
        // GMM : Rice & Gaussian method
        for (NSString *component in epiNameComponents) {
            double threshold;
            if ([component hasPrefix:@"GMM_"]) {
                threshold = [[component substringFromIndex:[@"GMM_" length]] floatValue];
                NSPredicate *thresholdPredicate = [NSPredicate predicateWithFormat:@"self.intensity >= %f", threshold];
                OSIROIMask *SegmentedMask = [myocardiumMask filteredROIMaskUsingPredicate:thresholdPredicate floatVolumeData:floatVolumeData];
                infarctMask = [infarctMask ROIMaskByUnioningWithMask:SegmentedMask];
            }
        }
        
        //  use a remote ROI - FWHM region
        OSIROI *regionROI = [roiManager CMRFirstROIWithNamePrefix:@"CMRSegTools: FWHMRegion" movieIndex:movieIndex pixIndex:pixIndex];
        if (regionROI) {
            OSIROIMask *regionMask = [regionROI ROIMaskForFloatVolumeData:normalFloatVolumeData];
            OSIROIMask *intersectedRegionMask = [regionMask ROIMaskByIntersectingWithMask:normalMyocardiumMask];
            if ([intersectedRegionMask maskRunCount]) {
                OSIROIFloatPixelData *regionPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:intersectedRegionMask floatVolumeData:normalFloatVolumeData] autorelease];
                float regionMean = [regionPixelData intensityMean];
                
                OSIROIFloatPixelData *floatPixelData = [myocardiumROI ROIFloatPixelDataForFloatVolumeData:normalFloatVolumeData];
                float regionMax = [floatPixelData intensityMax];
                
                NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"self.intensity > %f", regionMean + (regionMax-regionMean)/2];
                OSIROIMask *regionSegmentedMask = [normalMyocardiumMask filteredROIMaskUsingPredicate:searchPredicate floatVolumeData:normalFloatVolumeData];
                infarctMask = [infarctMask ROIMaskByUnioningWithMask:regionSegmentedMask];
                
                OSIMaskROI *regionIntersectROI = [[[OSIMaskROI alloc] initWithROIMask:intersectedRegionMask homeFloatVolumeData:floatVolumeData name:@"regionIntersectROI"] autorelease];
                NSColor *remoteColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRRemoteColor"]];
                CGFloat remoteOpacity = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRRemoteColorOpacity"];
                [regionIntersectROI setFillColor:[remoteColor colorWithAlphaComponent:remoteOpacity]];
                [roiManager addROI:regionIntersectROI];
            }
        }
        
        OSIROI* FWHM3DROI = [roiManager firstVisibleROIWithName:@"CMRSegTools: FWHM3D"];
        if (FWHM3DROI) {
            OSIROIMask *FWHM3DMask = [FWHM3DROI ROIMaskForFloatVolumeData:floatVolumeData];
            OSIROIMask *intersectedFWHM3DMask = [FWHM3DMask ROIMaskByIntersectingWithMask:myocardiumMask];
            if ([intersectedFWHM3DMask maskRunCount]) {
                OSIROIFloatPixelData *FWHM3DPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:intersectedFWHM3DMask floatVolumeData:floatVolumeData] autorelease];
                float regionMean = [FWHM3DPixelData intensityMean];
                
                OSIROIFloatPixelData *floatPixelData = [myocardiumROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData];
                float regionMax = [floatPixelData intensityMax];
                
                NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"self.intensity > %f", (regionMean + regionMax)/2];
                OSIROIMask *FWHM3DSegmentedMask = [myocardiumMask filteredROIMaskUsingPredicate:searchPredicate floatVolumeData:floatVolumeData];
                infarctMask = [infarctMask ROIMaskByUnioningWithMask:FWHM3DSegmentedMask];
                
                OSIMaskROI *FWHM3DIntersectROI = [[[OSIMaskROI alloc] initWithROIMask:intersectedFWHM3DMask homeFloatVolumeData:floatVolumeData name:@"regionIntersectROI3D"] autorelease];
                NSColor *FWHMColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRFWHMColor"]];
                CGFloat FWHMOpacity = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRFWHMColorOpacity"];
                [FWHM3DIntersectROI setFillColor:[FWHMColor colorWithAlphaComponent:FWHMOpacity]];
                [roiManager addROI:FWHM3DIntersectROI];
            }
        }
        
        NSArray* FWHM3Darray = [roiManager ROIsWithName:@"regionIntersectROI3D"];
        if ([FWHM3Darray count]>0) {
            OSIROI* intersectedFWHM3DROI = [FWHM3Darray objectAtIndex:0];
            OSIROIMask *intersectedFWHM3DMask = [intersectedFWHM3DROI ROIMaskForFloatVolumeData:floatVolumeData];
            if ([intersectedFWHM3DMask maskRunCount]) {
                OSIROIFloatPixelData *FWHM3DPixelData = [[[OSIROIFloatPixelData alloc] initWithROIMask:intersectedFWHM3DMask floatVolumeData:floatVolumeData] autorelease];
                float regionMean = [FWHM3DPixelData intensityMean];
                
                OSIROIFloatPixelData *floatPixelData = [myocardiumROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData];
                float regionMax = [floatPixelData intensityMax];
                
                NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"self.intensity > %f", (regionMean + regionMax)/2];
                OSIROIMask *FWHM3DSegmentedMask = [myocardiumMask filteredROIMaskUsingPredicate:searchPredicate floatVolumeData:floatVolumeData];
                infarctMask = [infarctMask ROIMaskByUnioningWithMask:FWHM3DSegmentedMask];
            }
        }
        
        // use a cutoff value stored in the epicardium ROI name
        for (NSString *component in epiNameComponents) {
            if ([component hasPrefix:@"Infarct_threshold_"]) {
                float tmin, tmax;
                if ([CMRSegTools parseRangeString:component prefix:@"Infarct_threshold_" min:&tmin max:&tmax]) {
                    NSPredicate *thresholdPredicate = [NSPredicate predicateWithFormat:@"self.intensity >= %f AND self.intensity <= %f", tmin, tmax];
                    OSIROIMask *thresholdMask = [myocardiumMask filteredROIMaskUsingPredicate:thresholdPredicate floatVolumeData:floatVolumeData];
                    infarctMask = [infarctMask ROIMaskByUnioningWithMask:thresholdMask];
                }
            }
        }
        
        // use the max of the myocardium for the FWHM
        for (NSString *component in epiNameComponents) {
            if ([component hasPrefix:@"FWHM Max"]) {
                OSIROIFloatPixelData *floatPixelData = [myocardiumROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData];
                float regionMax = [floatPixelData intensityMax];
                
                NSPredicate *thresholdPredicate = [NSPredicate predicateWithFormat:@"self.intensity >= %f", regionMax/2];
                OSIROIMask *thresholdMask = [myocardiumMask filteredROIMaskUsingPredicate:thresholdPredicate floatVolumeData:floatVolumeData];
                infarctMask = [infarctMask ROIMaskByUnioningWithMask:thresholdMask];
            }
        }
        
        OSIROI *importInfarctROI = [roiManager CMRFirstROIWithNamePrefix:@"CMRSegTools: MI by CMR42" movieIndex:movieIndex pixIndex:pixIndex];
        if (importInfarctROI) {
            NSArray *infarctNameComponents = [[importInfarctROI name] componentsSeparatedByString:@";"];
            for (NSString *component in infarctNameComponents) {
                if ([component hasPrefix:@"YES"]) {
                    OSIROIMask *importInfarctMask =[importInfarctROI ROIMaskForFloatVolumeData:floatVolumeData];
                    importInfarctMask = [importInfarctMask ROIMaskByIntersectingWithMask:myocardiumMask];
                    
                    OSIROI *importNRROI = [roiManager CMRFirstROIWithNamePrefix:@"CMRSegTools: NR by CMR42" movieIndex:movieIndex pixIndex:pixIndex];
                    if (importNRROI) {
                        NSArray *NRNameComponents = [[importNRROI name] componentsSeparatedByString:@";"];
                        for (NSString *component in NRNameComponents) {
                            if ([component hasPrefix:@"YES"]) {
                                OSIROIMask *importNRMask =[importNRROI ROIMaskForFloatVolumeData:floatVolumeData];
                                importNRMask = [importNRMask ROIMaskByIntersectingWithMask:myocardiumMask];
                                
                                importInfarctMask = [importInfarctMask ROIMaskBySubtractingMask:importNRMask];
                                if ([importNRMask maskRunCount]) {
                                    OSIMaskROI *noReflowROI = [[[OSIMaskROI alloc] initWithROIMask:importNRMask homeFloatVolumeData:floatVolumeData name:@"no-reflow"] autorelease];
                                    NSColor *noReflowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRNoReflowColor"]];
                                    CGFloat noReflowOpacity = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRNoReflowColorOpacity"];
                                    [noReflowROI setFillColor:[noReflowColor colorWithAlphaComponent:noReflowOpacity]];
                                    if ([importNRMask maskRunCount]) {
                                        [roiManager addROI:noReflowROI];
                                    }
                                }
                            }
                        }
                    }
                    infarctMask = importInfarctMask;
                }
            }
        }
        
        OSIROI *hmrfInfarctROI = [roiManager CMRFirstROIWithNamePrefix:@"hmrfMask" movieIndex:movieIndex pixIndex:pixIndex];
        if (hmrfInfarctROI){
            OSIROIMask *hmrfInfarctMask = [hmrfInfarctROI ROIMaskForFloatVolumeData:floatVolumeData];
            hmrfInfarctMask = [hmrfInfarctMask ROIMaskByIntersectingWithMask:myocardiumMask];
            infarctMask = [infarctMask ROIMaskByUnioningWithMask:hmrfInfarctMask];
        }
        
        
        OSIROIMask *wedgeClippedMyocardiumMask = myocardiumMask;
        
        OSIROIMask *nonWedgeClippedInfarct = nil;
        // filter out pixels that are not in the infarct wedge
        if (infarctAngleWedge) {
            OSIPathExtrusionROI *wedgeROI = [[[OSIPathExtrusionROI alloc] initWith:infarctAngleWedge slab:wedgeSlab homeFloatVolumeData:floatVolumeData name:@"wedge slab"] autorelease];
            OSIROIMask *wedgeMask = [wedgeROI ROIMaskForFloatVolumeData:floatVolumeData];
           
            nonWedgeClippedInfarct = infarctMask;

            if (infarctWedgeIsHealthy) {
                infarctMask = [infarctMask ROIMaskBySubtractingMask:wedgeMask];
                wedgeClippedMyocardiumMask = [myocardiumMask ROIMaskBySubtractingMask:wedgeMask];
            } else {
                infarctMask = [infarctMask ROIMaskByIntersectingWithMask:wedgeMask];
                wedgeClippedMyocardiumMask = [myocardiumMask ROIMaskByIntersectingWithMask:wedgeMask];
            }
        }

        if ([wedgeClippedMyocardiumMask maskRunCount]) {
            OSIMaskROI *wedgeClippedMyocardiumROI = [[[OSIMaskROI alloc] initWithROIMask:wedgeClippedMyocardiumMask homeFloatVolumeData:floatVolumeData name:@"wedgeClippedMyocardium"] autorelease];
            [wedgeClippedMyocardiumROI setFillColor:[[NSColor greenColor] colorWithAlphaComponent:0]];
            [roiManager addROI:wedgeClippedMyocardiumROI];
        }
        
        
        // add any include ROIs
        OSIROIMask *includeMask = [[[OSIROIMask alloc] init] autorelease];
        NSArray *includeROIs = [roiManager CMRROIsWithName:@"CMRSegTools: Include in Infarct" movieIndex:movieIndex pixIndex:pixIndex];
        for (OSIROI *includeROI in includeROIs) {
            includeMask = [[includeROI ROIMaskForFloatVolumeData:floatVolumeData] ROIMaskByUnioningWithMask:includeMask];
        }
        includeMask = [includeMask ROIMaskByIntersectingWithMask:myocardiumMask];
        infarctMask = [infarctMask ROIMaskByUnioningWithMask:includeMask];
        nonWedgeClippedInfarct = [nonWedgeClippedInfarct ROIMaskByUnioningWithMask:includeMask];
        
        
        // remove any exclude ROI
        OSIROIMask *excludeMask = [[[OSIROIMask alloc] init] autorelease];
        NSArray *excludeROIs = [roiManager CMRROIsWithName:@"CMRSegTools: Exclude from Infarct" movieIndex:movieIndex pixIndex:pixIndex];
        for (OSIROI *excludeROI in excludeROIs) {
            excludeMask = [[excludeROI ROIMaskForFloatVolumeData:floatVolumeData] ROIMaskByUnioningWithMask:excludeMask];
        }
        infarctMask = [infarctMask ROIMaskBySubtractingMask:excludeMask];
        nonWedgeClippedInfarct = [nonWedgeClippedInfarct ROIMaskBySubtractingMask:excludeMask];
        
        if ([infarctMask maskRunCount]) {
//        NSLog(@"mrs:");
//            for (NSValue *mrv in infarctMask.maskRuns) {
//                OSIROIMaskRun mr = mrv.OSIROIMaskRunValue;
//                NSLog(@"\t{{%lu,%lu},%lu,%lu,%f}", mr.widthRange.location, mr.widthRange.length, mr.heightIndex, mr.depthIndex, mr.intensity);
//                NSMutableString *s = [NSMutableString string];
//                for (NSUInteger i = 0; i < mr.widthRange.length; ++i) {
//                    float f; [floatVolumeData getFloat:&f atPixelCoordinateX:mr.widthRange.location+i y:mr.heightIndex z:mr.depthIndex];
//                    [s appendFormat:@"%f ", f];
//                }
//                NSLog(@"\t\t%@", s);
//            }
//            
//            NSLog(@"%@", NSStringFromN3AffineTransform(floatVolumeData.volumeTransform));
            
            OSIMaskROI *segmentedROI = [[[OSIMaskROI alloc] initWithROIMask:infarctMask homeFloatVolumeData:floatVolumeData name:@"segmented"] autorelease];
            NSColor *segmentedColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRMIColor"]];
            CGFloat segmentedOpacity = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRMIColorOpacity"];
            [segmentedROI setFillColor:[segmentedColor colorWithAlphaComponent:segmentedOpacity]];
            [roiManager addROI:segmentedROI];
        }

        if ([nonWedgeClippedInfarct maskRunCount]) {
            OSIMaskROI *nonWedgeClippedSegmentedROI = [[[OSIMaskROI alloc] initWithROIMask:nonWedgeClippedInfarct homeFloatVolumeData:floatVolumeData name:@"nonWedgeClippedSegmented"] autorelease];
            [roiManager addROI:nonWedgeClippedSegmentedROI];
        }
        
        OSIROIMask *noReflowMask = [[[OSIROIMask alloc] init] autorelease];
        NSArray *includeNoReflowROIs = [roiManager CMRROIsWithName:@"CMRSegTools: No-reflow" movieIndex:movieIndex pixIndex:pixIndex];
        for (OSIROI *includeNoReflowROI in includeNoReflowROIs) {
            noReflowMask = [[includeNoReflowROI ROIMaskForFloatVolumeData:floatVolumeData] ROIMaskByUnioningWithMask:noReflowMask];
        }
        noReflowMask = [noReflowMask ROIMaskByIntersectingWithMask:myocardiumMask];
        noReflowMask = [noReflowMask ROIMaskBySubtractingMask:infarctMask];
        
        if ([noReflowMask maskRunCount]) {
            OSIMaskROI *noReflowROI = [[[OSIMaskROI alloc] initWithROIMask:noReflowMask homeFloatVolumeData:floatVolumeData name:@"no-reflow"] autorelease];
            NSColor *noReflowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRNoReflowColor"]];
            CGFloat noReflowOpacity = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRNoReflowColorOpacity"];
            [noReflowROI setFillColor:[noReflowColor colorWithAlphaComponent:noReflowOpacity]];
            if ([noReflowMask maskRunCount]) {
                [roiManager addROI:noReflowROI];
            }
        }
        
        OSIROIMask *noReflowMaskHsu = [[[OSIROIMask alloc] init] autorelease];
        NSArray *includeNoReflowROIsHsu = [roiManager CMRROIsWithName:@"Hsu: No-reflow;yes" movieIndex:movieIndex pixIndex:pixIndex];
        for (OSIROI *includeNoReflowROIHsu in includeNoReflowROIsHsu) {
            noReflowMaskHsu = [[includeNoReflowROIHsu ROIMaskForFloatVolumeData:floatVolumeData] ROIMaskByUnioningWithMask:noReflowMaskHsu];
        }
        noReflowMaskHsu = [noReflowMaskHsu ROIMaskByIntersectingWithMask:myocardiumMask];
        noReflowMaskHsu = [noReflowMaskHsu ROIMaskBySubtractingMask:infarctMask];
        
        if ([noReflowMaskHsu maskRunCount]) {
            OSIMaskROI *noReflowROIHsu = [[[OSIMaskROI alloc] initWithROIMask:noReflowMaskHsu homeFloatVolumeData:floatVolumeData name:@"no-reflow"] autorelease];
            NSColor *noReflowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRNoReflowColor"]];
            CGFloat noReflowOpacity = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRNoReflowColorOpacity"];
            [noReflowROIHsu setFillColor:[noReflowColor colorWithAlphaComponent:noReflowOpacity]];
            if ([noReflowMaskHsu maskRunCount]) {
                [roiManager addROI:noReflowROIHsu];
            }
        }
        
        OSIROIMask *noReflowMaskHMRF = [[[OSIROIMask alloc] init] autorelease];
        NSArray *includeNoReflowROIsHMRF = [roiManager CMRROIsWithName:@"hmrf: No-reflow;yes" movieIndex:movieIndex pixIndex:pixIndex];
        for (OSIROI *includeNoReflowROIHMRF in includeNoReflowROIsHMRF) {
            noReflowMaskHMRF = [[includeNoReflowROIHMRF ROIMaskForFloatVolumeData:floatVolumeData] ROIMaskByUnioningWithMask:noReflowMaskHMRF];
        }
        noReflowMaskHMRF = [noReflowMaskHMRF ROIMaskByIntersectingWithMask:myocardiumMask];
        noReflowMaskHMRF = [noReflowMaskHMRF ROIMaskBySubtractingMask:infarctMask];
        
        if ([noReflowMaskHMRF maskRunCount]) {
            OSIMaskROI *noReflowROIHMRF = [[[OSIMaskROI alloc] initWithROIMask:noReflowMaskHMRF homeFloatVolumeData:floatVolumeData name:@"no-reflow"] autorelease];
            NSColor *noReflowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"CMRNoReflowColor"]];
            CGFloat noReflowOpacity = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CMRNoReflowColorOpacity"];
            [noReflowROIHMRF setFillColor:[noReflowColor colorWithAlphaComponent:noReflowOpacity]];
            if ([noReflowMaskHMRF maskRunCount]) {
                [roiManager addROI:noReflowROIHMRF];
            }
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"values.CMRShowSegements"]) {
        [self _roisDidUpdateNotification:nil];
    }
}

+ (BOOL)isROI:(OSIROI *)roi onPixIndex:(NSInteger)pixIndex dicomToPixTransform:(N3AffineTransform)dicomToPixTransform
{
    // so we now know that this is an real OSIROI, but is it on the right slice?
    if ([roi isKindOfClass:[OSIMaskROI class]]) {
        OSIROIMask *mask = [roi performSelector:@selector(mask)]; // perform selector because I forgot to add the accessor to the .h
        if ([mask maskRunCount] > 0) {
            if ([[[mask maskRuns] lastObject] OSIROIMaskRunValue].depthIndex == pixIndex)
                return YES;
        }
    } else if ([roi isKindOfClass:[OSIPathExtrusionROI class]]) {
        N3BezierPath *path = [roi performSelector:@selector(path)]; // perform selector because I forgot to hook up the accessor for bezierPath
        N3Vector endpoint = N3VectorZero;
        [path elementAtIndex:0 control1:NULL control2:NULL endpoint:&endpoint];
        if (round(N3VectorApplyTransform(endpoint, dicomToPixTransform).z) == 0) {
            return YES;
        }
    } else if ([roi isKindOfClass:[CMRTextROI class]]) {
        N3Vector position = [(CMRTextROI *)roi position];
        if (round(N3VectorApplyTransform(position, dicomToPixTransform).z) == 0) {
            return YES;
        }
    }
    return NO;
}

- (void)menuWillOpen:(NSMenu *)menu {
    // assume this is the T1Preprocessing menu
    [menu removeAllItems];
    for (NSDictionary *filter in [[NSUserDefaults standardUserDefaults] arrayForKey:@"CMRT1PreprocessingFilters"]) {
        NSString *title = filter[@"name"], *f = filter[@"filter"];
        if (!f) f = @"name CONTAINS[cd] \"MAGIR\"";
        if (!title) title = [NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"Unnamed filter", nil), f];
        NSMenuItem *mi = [menu addItemWithTitle:title action:@selector(CMRT1Preprocessing:) keyEquivalent:@""];
        mi.target = self;
        mi.representedObject = filter;
    }
}

+ (BOOL)parseRangeString:(NSString *)str prefix:(NSString *)prefix min:(float *)min max:(float *)max {
    if (![str hasPrefix:prefix])
        return NO;
    
    NSArray<NSString *> *mm = [[str substringFromIndex:prefix.length] componentsSeparatedByString:@"/"];
    *min = -MAXFLOAT;
    *max = MAXFLOAT;
    
    if (mm.count > 0 && mm[0].length)
        *min = mm[0].floatValue;
    if (mm.count > 1 && mm[1].length)
        *max = mm[1].floatValue;
    
    return YES;
}

+ (NSString *)rangeStringWithPrefix:(NSString *)prefix min:(float)min max:(float)max {
    return [NSString stringWithFormat:@"%@%@/%@", prefix,
            (min != -MAXFLOAT)? [NSString stringWithFormat:@"%.3f", min] : @"",
            (max != MAXFLOAT)? [NSString stringWithFormat:@"%.3f", max] : @""];
}

//_______ACTIVATION_CODE_______
#pragma mark - ACTIVATION CODE VERIFICATION

#if ACTIVATION_CODE

 /*
 REFACTOR: Removed for PLoS ONE publication.
 */


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

 /*
 REFACTOR: Removed for PLoS ONE publication.
 */

//_______END_ACTIVATION_CODE_______
#pragma clang diagnostic pop

#else
 /*
 REFACTOR: Removed for PLoS ONE publication.
 */
#endif

@end
