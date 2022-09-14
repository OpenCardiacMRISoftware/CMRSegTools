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
//  CMRT1Preprocessing.m
//  CMRSegTools
//
//  Created by Alessandro Volz on 5/4/16.
//  Copyright © 2016 volz.io. All rights reserved.
//

#import "CMRT1Preprocessing.h"
#import "CMRWindowController.h"
#import <OsiriX/DicomStudy.h>
#import <OsiriX/DicomSeries.h>
#import <OsiriX/DicomImage.h>
#import <OsiriX/BrowserController.h>
#import <OsiriX/ViewerController.h>
#import <OsiriX/ToolbarPanel.h>
#import <OsiriX/DCMPix.h>
#import <OsiriX/N3Geometry.h>
#import <OsiriX/DicomDatabase.h>
#import <OsiriX/Notifications.h>
#import <OsiriX/DCMTKSeriesQueryNode.h>
#import <OsiriX/NSThread+N2.h>
#import <OsiriX/ThreadModalForWindowController.h>
#import <OsiriX/QueryController.h>

@interface BrowserController (CMRSegTools)
- (void)CMRSegTools_setDontUpdatePreviewPane:(BOOL)flag;
@end

@interface CMRT1PreprocessingPic ()

@property (retain) NSURL *url;
@property NSUInteger frame;

@end

@implementation CMRT1PreprocessingPic

@synthesize url = _url;
@synthesize frame = _frame;

- (instancetype)initWithURL:(NSURL *)url frame:(NSUInteger)frame {
    if (!(self = [super init]))
        return nil;
    
    self.url = url;
    self.frame = frame;
    
    return self;
}

- (void)dealloc {
    self.url = nil;
    [super dealloc];
}

@end

@interface CMRT1PreprocessingWindowController : CMRWindowController

@end

@implementation CMRT1Preprocessing

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // DCMTK requires the DCMDICTPATH environmental variable to point to the location of a dicom.dic, we address them to the one that's available inside OsiriX
        NSURL *dic = [[NSBundle mainBundle] URLForResource:@"dicom" withExtension:@"dic"];
        if (dic)
            setenv("DCMDICTPATH", dic.fileSystemRepresentation, false);
    });
}

+ (void)_seriesIn:(id)obj into:(NSMutableArray *)collection {
    if ([obj isKindOfClass:DicomSeries.class] || [obj isKindOfClass:DCMTKSeriesQueryNode.class])
        if (![collection containsObject:obj])
            [collection addObject:obj];
    
    if ([obj isKindOfClass:[NSArray class]])
        for (id i in obj)
            [self _seriesIn:i into:collection];
    
    if ([obj isKindOfClass:[DicomStudy class]])
        [self _seriesIn:[[(DicomStudy *)obj series] allObjects] into:collection];
    if ([obj isKindOfClass:DCMTKStudyQueryNode.class]) {
        if (![obj children])
            [obj queryWithValues:nil];
        [self _seriesIn:[obj children] into:collection];
    }
    
    if ([obj isKindOfClass:[DicomImage class]])
        [self _seriesIn:[(DicomImage *)obj series] into:collection];
}

+ (void)proceed:(NSDictionary *)fd {
    BrowserController *bc = [BrowserController currentBrowser];
    
    // get selected series
    NSMutableArray *series = [NSMutableArray array]; // contains DicomSeries and DCMTKSeriesQueryNode
    if ([bc isKindOfClass:[BrowserController class]]) {
        if (bc.window.firstResponder == bc.oMatrix) {
            for (NSCell* cell in [[bc oMatrix] selectedCells])
                [series addObject:[[bc matrixViewArray] objectAtIndex:[cell tag]]];
        } else
            [self.class _seriesIn:[bc databaseSelection] into:series];
    }
    
//    NSString *filter = [[NSUserDefaults standardUserDefaults] stringForKey:@"CMRT1PreprocessingFilter"];
//    NSInteger filterType = [[NSUserDefaults standardUserDefaults] integerForKey:@"CMRT1PreprocessingFilterType"];
    NSString *filter = fd[@"filter"];
    NSInteger filterType = [fd[@"type"] integerValue];
    
    __block NSString *err = nil;
    NSPredicate *predicate = nil;
    if (filterType && filter.length) @try {
        predicate = [NSPredicate predicateWithFormat:filter];
    } @catch (NSException *e) {
        NSLog(@"Warning: couldn't use CMRT1Preprocessing filter as a predicate, will be used as matching string (%@)", filter);
        err = [NSString stringWithFormat:NSLocalizedString(@"The provided filter (%@) couldn't be interpreted as a predicate.", nil), filter];
    }
    
    if (!predicate) {
        if (!filter.length)
            filter = @"MAGIR";
        if (![filter containsString:@"*"])
            predicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", filter];
        else predicate = [NSPredicate predicateWithFormat:@"name LIKE[cd] %@", filter];
    }
    
    [series filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(DicomSeries *serie, NSDictionary *bindings) {
        // remove OsiriX private series // TODO: DCMTKSeriesQueryNodes don't declare their seriesSOPClassUID
        if ([serie isKindOfClass:DicomSeries.class] && ![DicomStudy displaySeriesWithSOPClassUID:serie.seriesSOPClassUID andSeriesDescription:serie.name])
            return NO;
        // select all serieses with matching name
        @try {
            return [predicate evaluateWithObject:serie];
        } @catch (NSException *e) {
            err = [NSString stringWithFormat:NSLocalizedString(@"The provided filter predicate (%@) couldn't be used in our context.", nil), filter];
        }
        
        return NO;
    }]];

    // is selection valid?
    if (series.count < 1) {
        NSString *title = NSLocalizedString(@"Invalid selection", nil);
        if (!err)
            err = NSLocalizedString(@"The filter didn't match any series.", nil);
        else title = NSLocalizedString(@"Invalid filter", nil);
        NSBeginAlertSheet(title, nil, nil, nil, [bc window], nil, nil, nil, nil, @"%@", err);
        return;
    }
    
    void (^showtime)() = ^{
        [ViewerController closeAllWindows];
        
        [bc CMRSegTools_setDontUpdatePreviewPane:YES];
        [bc viewerDICOMInt:NO dcmFile:[series sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES]]] viewer:nil];
        [bc CMRSegTools_setDontUpdatePreviewPane:NO];
        
        CMRWindowController *wc = [[CMRT1PreprocessingWindowController alloc] initWithContentViewController:[[[CMRT1Preprocessing alloc] initWithNibName:nil bundle:nil] autorelease]];
        wc.window.level = NSFloatingWindowLevel;
        wc.window.hidesOnDeactivate = YES;
        wc.window.title = NSLocalizedString(@"CMRT1Preprocessing", nil);
        wc.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        
        NSWindow *tp = [[[[ViewerController getDisplayed2DViewers] firstObject] toolbarPanel] window];
        [wc.window setFrameOrigin:NSMakePoint(NSMinX(tp.frame)+5, NSMinY(tp.frame)-NSHeight(wc.window.frame)+10)];
        
        [wc.window orderFront:self];
        
        [[NSNotificationCenter defaultCenter] addObserver:wc.contentViewController selector:@selector(_panelWillClose:) name:NSWindowWillCloseNotification object:wc.window];
        [[NSNotificationCenter defaultCenter] addObserver:wc.contentViewController selector:@selector(_viewerClose:) name:OsirixCloseViewerNotification object:nil];
    };
    
    NSMutableArray<DCMTKSeriesQueryNode *> *remotes = [NSMutableArray arrayWithArray:[series filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF isKindOfClass: %@", DCMTKSeriesQueryNode.class]]];
    DicomDatabase *db = bc.database;
    for (DCMTKSeriesQueryNode *remote in [NSArray arrayWithArray:remotes]) {
        DicomSeries *s = [[db objectsForEntity:db.seriesEntity predicate:[NSPredicate predicateWithFormat:@"seriesDICOMUID = %@", remote.seriesInstanceUID]] firstObject];
        if (s) {
            [remotes removeObject:remote];
            [series removeObject:remote];
            [series addObject:s];
        }
    }

    if (remotes.count) {
        NSThread *thread = [NSThread performBlockInBackground:^{
            NSThread *thread = [NSThread currentThread];

            [QueryController retrieveStudies:remotes showErrors:NO];

            while (!thread.isCancelled && remotes.count) @autoreleasepool {
                DicomDatabase *db = [bc.database independentDatabase];
                
                for (DCMTKSeriesQueryNode *remote in [NSArray arrayWithArray:remotes]) {
                    DicomSeries *s = [[db objectsForEntity:db.seriesEntity predicate:[NSPredicate predicateWithFormat:@"seriesDICOMUID = %@", remote.seriesInstanceUID]] firstObject];
                    if (s) {
                        [remotes removeObject:remote];
                        [series removeObject:remote];
                        [series addObject:s.objectID];
                    }
                }
                
                [NSThread sleepForTimeInterval:0.01];
            }
            
            if (!thread.isCancelled)
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    for (id s in [NSArray arrayWithArray:series])
                        if ([s isKindOfClass:NSManagedObjectID.class]) {
                            DicomSeries *ss = [db objectWithID:s];
                            [series removeObject:s];
                            if (ss) [series addObject:ss];
                        }
                    
                    showtime();
                }];
        }];
        
        thread.name = NSLocalizedString(@"Retrieving remote series...", nil);
        thread.supportsCancel = YES;
        [thread startModalForWindow:bc.window];
    } else
        showtime();
}

- (void)_panelWillClose:(NSNotification *)n {
    [[n.object windowController] release];
}

- (void)_viewerClose:(NSNotification *)n {
    [NSOperationQueue.mainQueue addOperationWithBlock:^{
        if ([ViewerController numberOf2DViewer] == 0)
            [self.view.window close];
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)loadView {
    NSStackView *stack = [[[NSStackView alloc] initWithFrame:NSZeroRect] autorelease];
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    stack.spacing = 6;
    stack.edgeInsets = NSEdgeInsetsMake(6, 6, 6, 6);

    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    [stack setHuggingPriority:NSLayoutPriorityDragThatCanResizeWindow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [stack setHuggingPriority:NSLayoutPriorityDragThatCanResizeWindow forOrientation:NSLayoutConstraintOrientationVertical];
    
    NSButton *b = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    
    b.title = NSLocalizedString(@"Select T1 and export", nil);

    if ([b respondsToSelector:@selector(setControlSize:)])
        b.controlSize = NSSmallControlSize;
    else [b.cell setControlSize:NSSmallControlSize];
    b.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]];
    
    b.buttonType = NSMomentaryLightButton;
    b.bezelStyle = NSRoundRectBezelStyle;
    
    b.target = self;
    b.action = @selector(_action:);
    
    [stack addView:b inGravity:NSStackViewGravityTop];
    
    self.view = stack;
}

- (void)_action:(NSButton *)b {
    NSError *error = nil;
    @try {
        NSArray<DCMPix *> *pix = [[ViewerController getDisplayed2DViewers] valueForKeyPath:@"imageView.curDCM"];
        
        // sort
        
        pix = [pix sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"seriesObj.id" ascending:YES]]];
        
//        N3Vector * const vectors = [[NSMutableData dataWithLength:sizeof(N3Vector)*pix.count] mutableBytes];
//        for (NSUInteger i = 0; i < pix.count; ++i)
//            vectors[i] = N3VectorMake(pix[i].originX, pix[i].originY, pix[i].originZ);
//        N3Line l = [self.class lineWithVectors:vectors count:pix.count];
//        CGFloat len = N3VectorLength(l.vector);
//        pix = [pix sortedArrayUsingComparator:^NSComparisonResult(DCMPix *p1, DCMPix *p2) {
//            CGFloat f1 = N3VectorDotProduct(N3VectorSubtract(N3VectorMake(p1.originX, p1.originY, p1.originZ), l.point), l.vector) / len;
//            CGFloat f2 = N3VectorDotProduct(N3VectorSubtract(N3VectorMake(p2.originX, p2.originY, p2.originZ), l.point), l.vector) / len;
//            if (f1 > f2) return NSOrderedDescending;
//            if (f1 == f2) return NSOrderedSame;
//            return NSOrderedAscending;
//        }];
        
        // clone
        
        NSMutableArray<CMRT1PreprocessingPic *> *pics = [NSMutableArray array];
        for (DCMPix *pic in pix)
            [pics addObject:[[[CMRT1PreprocessingPic alloc] initWithURL:[NSURL fileURLWithPath:pic.sourceFile] frame:pic.frameNo] autorelease]];
        
        NSUInteger seriesNumber = 1;
        for (DicomSeries *s in pix.firstObject.studyObj.series)
            if (s.id.unsignedIntegerValue >= seriesNumber)
                seriesNumber = s.id.unsignedIntegerValue+1;
        
        NSArray<NSURL *> *picfiles = [self clone:pics seriesDescription:@"CMRT1Preprocessed" seriesNumber:seriesNumber
                                      intoTmpDir:[NSURL fileURLWithPath:[[DicomDatabase databaseForContext:pix.firstObject.studyObj.managedObjectContext] tempDirPath] isDirectory:YES] error:&error];
        
        if (error)
            return;
        
        DicomDatabase *db = [DicomDatabase databaseForContext:pix.firstObject.studyObj.managedObjectContext];

        NSMutableArray<NSString *> *dbfiles = [NSMutableArray array];
        for (NSURL* picfile in picfiles) {
            NSString* dbPath = [db uniquePathForNewDataFileWithExtension:@"dcm"];
            [[NSFileManager defaultManager] moveItemAtPath:picfile.path toPath:dbPath error:NULL];
            [dbfiles addObject:dbPath];
        }
        
        NSArray<NSManagedObjectID *> *ids = [db addFilesAtPaths:dbfiles];
        NSArray<DicomImage *> *images = [db objectsWithIDs:ids];
        
        // done
        
        [ViewerController closeAllWindows];
        [self.class _openSeries:images.firstObject.series];
    } @finally {
        [b.window close];
        if (error)
            [[NSAlert alertWithError:error] beginSheetModalForWindow:[[BrowserController currentBrowser] window] completionHandler:nil];
    }
}

+ (ViewerController *)_openSeries:(DicomSeries *)series /*clut:(NSString*)clut*/ {
    BrowserController *bc = [BrowserController currentBrowser];
    
    [bc selectThisStudy:series.study];
    [bc refreshMatrix:self];
    
    NSInteger i = [bc.matrixViewArray indexOfObject:series];
    [bc.oMatrix selectCellWithTag:i];
    
    [bc viewerDICOMInt:NO dcmFile:@[series] viewer:nil];

    NSArray* viewersAfter = [ViewerController getDisplayed2DViewers];
    ViewerController* vc = [[viewersAfter filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"currentSeries = %@", series]] lastObject];
    
//    if (clut)
//        [vc ApplyCLUTString:clut];
    
    return vc;
}

/*+ (N3Line)lineWithVectors:(N3Vector *)vectors count:(NSUInteger)numVectors {
    if (numVectors < 2)
        return N3LineInvalid;
    
    if (numVectors == 2)
        return N3LineMake(vectors[0], N3VectorSubtract(vectors[1], vectors[0]));
    
#   define N 3
#   define LDA N

    // calculate center of mass
    __CLPK_doublereal c[3] = {0,0,0};
    for (CFIndex i = 0; i < numVectors; ++i) {
        c[0] += vectors[i].x; c[1] += vectors[i].y; c[2] += vectors[i].z; }
    c[0] /= numVectors; c[1] /= numVectors; c[2] /= numVectors;
    
    // assemble covariance matrix - column-wise matrix indexes: [ 0 3 6 ]
    //                                                          [ x 4 7 ]
    //                                                          [ x x 8 ]
    __CLPK_doublereal a[LDA*N] = {0,0,0,0,0,0,0,0,0}; // input covariance, output eigenvectors
    for (CFIndex i = 0; i < numVectors; ++i) {
        __CLPK_doublereal d[3] = {vectors[i].x-c[0], vectors[i].y-c[1], vectors[i].z-c[2]};
        a[0] += d[0]*d[0];
        a[3] += d[0]*d[1];
        a[4] += d[1]*d[1];
        a[6] += d[0]*d[2];
        a[7] += d[1]*d[2];
        a[8] += d[2]*d[2];
    }
    
    // compute eigenvalues and eigenvectors
    
    __CLPK_integer n = N, lda = LDA, info = 0, lwork = -1, liwork = -1, iwkopt;
    __CLPK_doublereal w[N]; // the output eigenvalues
    __CLPK_doublereal wkopt;
    
    dsyevd("V", "U", &n, a, &lda, w, &wkopt, &lwork, &iwkopt, &liwork, &info);
    
    lwork = (int)wkopt;
    __CLPK_doublereal* work = (__CLPK_doublereal*)calloc(lwork, sizeof(__CLPK_doublereal));
    liwork = iwkopt;
    __CLPK_integer* iwork = (__CLPK_integer*)calloc(liwork, sizeof(__CLPK_integer));
    
    dsyevd("V", "U", &n, a, &lda, w, work, &lwork, iwork, &liwork, &info);
    
    free(iwork);
    free(work);

#   undef N
#   undef LDA

    // return the line
    
    if (info != 0) // lapack error
        return N3LineInvalid;
    
    return N3LineMake(N3VectorMake(c[0], c[1], c[2]), N3VectorMake(a[6], a[7], a[8]));
}*/

@end

@implementation CMRT1PreprocessingWindowController

+ (Class)NSWindowClass {
    return NSPanel.class;
}

+ (NSUInteger)styleMask {
    return NSTitledWindowMask|NSClosableWindowMask|NSNonactivatingPanelMask|NSUtilityWindowMask;
}

+ (NSRect)contentRect {
    return NSZeroRect;
}

@end

@implementation BrowserController (CMRSegTools)

- (void)CMRSegTools_setDontUpdatePreviewPane:(BOOL)flag {
    dontUpdatePreviewPane = flag;
}

@end
