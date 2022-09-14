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
//  CMRHistogramWindowController+BEASSegmenter.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 11/28/12.
//  Copyright (c) 2012 Spaltenstein Natural Image. All rights reserved.
//



#import "CMRHistogramWindowController.h"

#import "CMRSegTools.h"
#import "OsiriX+CMRSegTools.h"

#import <OsiriX/ViewerController.h>
#import <OsiriX/DCMPix.h>
#import <OsiriX/DCMView.h>
#import <OsiriX/ROI.h>
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/OSIROIManager.h>
#import <OsiriX/OSIROI.h>
#import <OsiriX/Notifications.h>

#import "Local2PhasesBEAS2DPolarCoupled.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winconsistent-missing-override"
#import <vtkPolyData.h>
#import <vtkImageImport.h>
#import <vtkMetaImageReader.h>
#pragma clang diagnostic pop

@interface CMRHistogramWindowController (BEASSegmenterPrivate)

- (NSString *)commentFromVtkMeshPoints:(vtkPoints *)vtkPoints;
- (vtkPoints *)vtkMeshPointsFromComment:(NSString *)comment;

@end


@implementation CMRHistogramWindowController (BEASSegmenter)

- (IBAction)runBEAS:(id)sender
{
    [self runBEASOnMovieIndex:[self.volumeWindow.viewerController curMovieIndex] pixIndex:[[self.volumeWindow.viewerController imageView] curImage] constrainToPixPoints:nil];
}

- (void)runBEAS:(id)sender constrainToPixPoints:(NSArray *)pixPoints
{
    [self runBEASOnMovieIndex:[self.volumeWindow.viewerController curMovieIndex] pixIndex:[[self.volumeWindow.viewerController imageView] curImage] constrainToPixPoints:pixPoints];
}

- (void)runBEASOnMovieIndex:(NSInteger)movieIndex pixIndex:(NSInteger)pixIndex constrainToPixPoints:(NSArray *)pixPoints // NSPoints stored as NSValues
{
    // the point of this will be to run the BEAS segmenter
    // since this code is a bit different, for now I will not hesitate to break out of the plugin SDK
    
    // first we need to find the view we are interested in
    
    // all fine and dandy, but let's try to just get the code to execute
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"BEASNbPoints":@64, @"BEASScaleContour":@2, @"BEASScaleThickness":@4, @"BEASNbIter":@200}];
    
    ViewerController *viewerController = [self.volumeWindow viewerController];
    DCMView *view = [[viewerController imageViews] objectAtIndex:movieIndex];
    DCMPix *pix = [[view dcmPixList] objectAtIndex:pixIndex];
    float *fimage = [pix fImage];
    long pwidth = [pix pwidth];
    long pheight = [pix pheight];
    double pixelSpacingX = [pix pixelSpacingX];
//    double pixelSpacingY = [pix pixelSpacingY];

    
    // get the ROI we are dealing with
    OSIROI *outsideROI = [self.volumeWindow.ROIManager visibleEpicardialROI];
    OSIROI *insideROI = [self.volumeWindow.ROIManager visibleEndocardialROI];
    
    if (outsideROI == nil || insideROI == nil) {
        return;
    }

    ROI *outsideBaseROI = [[outsideROI osiriXROIs] anyObject];
    ROI *insideBaseROI = [[insideROI osiriXROIs] anyObject];
    
    if (([outsideBaseROI type] != tCPolygon && [outsideBaseROI type] != tPencil) || ([insideBaseROI type] != tCPolygon && [insideBaseROI type] != tPencil)) {
        return;
    }

    int NbPoints = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"BEASNbPoints"];
    int ScaleContour = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"BEASScaleContour"];
    int ScaleThickness = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"BEASScaleThickness"];
    int NbIter = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"BEASNbIter"];

    NSPoint centroid = [insideBaseROI centroid];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    double insideAreaCm = [insideBaseROI roiArea];
    double outsideAreaCm = [outsideBaseROI roiArea];
#pragma clang diagnostic pop
    
    double insideRadiusCm = sqrt(insideAreaCm/M_PI);
    double outsideRadiusCm = sqrt(outsideAreaCm/M_PI);

    double insideRadiusMm = insideRadiusCm * 10.0;
    double outsideRadiusMm = outsideRadiusCm * 10.0;
    
    insideRadiusMm /= pixelSpacingX;
    outsideRadiusMm /= pixelSpacingX;
    
    vtkImageImport *image = vtkImageImport::New();
    image->SetDataScalarTypeToFloat();
    image->SetImportVoidPointer(fimage);
//    image->SetDataSpacing(pixelSpacingX, pixelSpacingY, 1);
    image->SetWholeExtent(0,(int)pwidth-1, 0,(int)pheight-1, 0,0);
    image->SetDataExtentToWholeExtent();
    image->Update();

    /// Read image
    
//    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"t2_stir_case_2" ofType:@"mhd"];
//    const char* systemPath = [filePath fileSystemRepresentation];
//    
//    vtkMetaImageReader* reader = vtkMetaImageReader::New();
//    reader->SetFileName(systemPath);
//    reader->Update();

//    int NbPoints = [[outsideBaseROI points] count];
//    int NbPoints = 64;
//    int ScaleContour = 2 / pixelSpacingX;
//    int ScaleThickness = 4 / pixelSpacingX;
//    int ScaleContour = 2;

    double XCenter = centroid.x;
    double YCenter = centroid.y;
    double RadiusEndo = insideRadiusMm;
    double RadiusEpi = outsideRadiusMm;
    
    Local2PhasesBEAS2DPolarCoupled* segmentor = new Local2PhasesBEAS2DPolarCoupled();
    segmentor->SetScale( ScaleContour, ScaleThickness );
    segmentor->SetCenterPoint( XCenter, YCenter, 0 );
    segmentor->SetNumberOfThetaSamples( NbPoints );
    segmentor->SetNumberOfIteration( NbIter );
    segmentor->SetInputVolume( image->GetOutput() );

    vtkPoints* savedEndoMeshPoints = [self vtkMeshPointsFromComment:insideBaseROI.comments];
    vtkPoints* savedEpiMeshPoints = [self vtkMeshPointsFromComment:outsideBaseROI.comments];

    if (pixPoints && savedEndoMeshPoints && savedEpiMeshPoints) { // if we have
        vtkPoints *userPoints = vtkPoints::New();
        for (NSValue *value in pixPoints) {
            NSPoint point = [value pointValue];
            userPoints->InsertNextPoint(point.x, point.y , 0);
        }
        segmentor->SetUserPoints(userPoints);
        userPoints->Delete();
        segmentor->SetInitialVtkMeshEndo(savedEndoMeshPoints);
        segmentor->SetInitialVtkMeshEpi(savedEpiMeshPoints);
    } else {
        segmentor->SetInitialRadius( RadiusEndo, RadiusEpi );
    }
    if (savedEndoMeshPoints) {
        savedEndoMeshPoints->Delete();
    }
    if (savedEpiMeshPoints) {
        savedEpiMeshPoints->Delete();
    }

    segmentor->Update();

    vtkPoints *ptsEndo = segmentor->GetEndoPoints();
    vtkPoints *ptsEpi = segmentor->GetEpiPoints();
    
    
    /// Display Endo points
    for ( int i=0; i<NbPoints; i++ )
    {
        double pos[3];
        ptsEndo->GetPoint(i,pos);
        
        NSLog(@"found endoPoint %f, %f, %f", pos[0], pos[1], pos[2]);
        
        NSPoint endoPoint = NSMakePoint(pos[0], pos[1]);
//        endoPoint.x *= pixelSpacingX;
//        endoPoint.y *= pixelSpacingY;
        
        if (i<[[insideBaseROI points] count]) {
            [insideBaseROI setPoint:endoPoint atIndex:i];
        } else {
            [insideBaseROI addPoint:endoPoint];
        }
    }

    
    while ([[insideBaseROI points] count] > NbPoints) {
        [[insideBaseROI points] removeLastObject];
    }
    
    /// Display Epi points
    for ( int i=0; i<NbPoints; i++ )
    {

        double pos[3];
        ptsEpi->GetPoint(i,pos);
        
        NSPoint epiPoint = NSMakePoint(pos[0], pos[1]);
//        epiPoint.x *= pixelSpacingX;
//        epiPoint.y *= pixelSpacingY;
        
        if (i<[[outsideBaseROI points] count]) {
            [outsideBaseROI setPoint:epiPoint atIndex:i];
        } else {
            [outsideBaseROI addPoint:epiPoint];
        }
    }

    while ([[outsideBaseROI points] count] > NbPoints) {
        [[outsideBaseROI points] removeLastObject];
    }

    ptsEndo->Delete();
    ptsEpi->Delete();

    // add the endo/epi mesh points to the ROI comments
    vtkPoints *endoMeshPts = segmentor->GetVtkMeshEndo();
    insideBaseROI.comments = [self commentFromVtkMeshPoints:endoMeshPts];
    endoMeshPts->Delete();

    vtkPoints *epiMeshPts = segmentor->GetVtkMeshEpi();
    outsideBaseROI.comments = [self commentFromVtkMeshPoints:epiMeshPts];
    epiMeshPts->Delete();

    [view setNeedsDisplay:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:OsirixROIChangeNotification object:insideBaseROI userInfo: nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:OsirixROIChangeNotification object:outsideBaseROI userInfo: nil];

    delete segmentor;
    image->Delete();
}

@end



@implementation CMRHistogramWindowController (BEASSegmenterPrivate)

- (NSString *)commentFromVtkMeshPoints:(vtkPoints *)vtkPoints
{
    NSMutableString *meshComment = [NSMutableString stringWithString:@"MeshPoints"];

    for (int i = 0; i < vtkPoints->GetNumberOfPoints(); i++) {
        double pos[3];
        vtkPoints->GetPoint(i,pos);

        [meshComment appendFormat:@"_(%.4f_%.4f_%.4f)", pos[0], pos[1], pos[2]];
    }

    return meshComment;
}

- (vtkPoints *)vtkMeshPointsFromComment:(NSString *)comment
{
    NSScanner *scanner = [NSScanner scannerWithString:comment];

    vtkPoints *pts = vtkPoints::New();

    if ([scanner scanString:@"MeshPoints" intoString:NULL] == NO) {
        pts->Delete();
        return NULL;
    }

    double point[3];
    while (YES) {

        if ([scanner scanString:@"_" intoString:NULL] == NO) {
            break;
        }

        if ([scanner scanString:@"(" intoString:NULL] == NO) {
            pts->Delete();
            return NULL;
        }

        if ([scanner scanDouble:&(point[0])] == NO) {
            pts->Delete();
            return NULL;
        }

        if ([scanner scanString:@"_" intoString:NULL] == NO) {
            pts->Delete();
            return NULL;
        }
        
        if ([scanner scanDouble:&(point[1])] == NO) {
            pts->Delete();
            return NULL;
        }

        if ([scanner scanString:@"_" intoString:NULL] == NO) {
            pts->Delete();
            return NULL;
        }

        if ([scanner scanDouble:&(point[2])] == NO) {
            pts->Delete();
            return NULL;
        }

        if ([scanner scanString:@")" intoString:NULL] == NO) {
            pts->Delete();
            return NULL;
        }
        pts->InsertNextPoint(point[0], point[1], point[2]);
    }

    return pts;
}



@end











