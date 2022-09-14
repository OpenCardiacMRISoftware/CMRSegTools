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
//  hsu.mm
//  CMRSegTools
//
//  Created by Coralie Vandroux on 6/14/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "hsu.h"
#import "OsiriX+CMRSegTools.h"

@interface hsu ()
@property (nonatomic, readwrite, retain) OSIVolumeWindow *volumeWindow;
@end

@implementation hsu

@synthesize volumeWindow = _volumeWindow;

// initialization
- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow
{
    self.volumeWindow = volumeWindow;
    
    imageMyo = ImageTypeFloat3D::New();
    meanHealthy = 0;
    sdHealthy = 0;
    
    return self;
}

// stack in ITK
- (ImageTypeFloat3D::Pointer)WrapImageFloat3D
{
    ImageTypeFloat3D::Pointer image;
    ImportFilterTypeFloat3D::Pointer importFilter = ImportFilterTypeFloat3D::New();
    ImportFilterTypeFloat3D::SizeType size;
    ImportFilterTypeFloat3D::IndexType start;
    ImportFilterTypeFloat3D::RegionType region;
    
    DCMPix *firstPix = [[[self.volumeWindow viewerController] pixList] objectAtIndex:0];
    int slices = (int)[[[self.volumeWindow viewerController] pixList] count];
    
    //Size Width * Height * NoOfSlices
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    size[2] = slices;
    long bufferSize = size[0] * size[1] * size[2];
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    
    double voxelSpacing[3];
    double originConverted[3];
    double vectorOriginal[9];
    double origin[3];
    origin[0] = [firstPix originX];
    origin[1] = [firstPix originY];
    origin[2] = [firstPix originZ];
    
    [firstPix orientationDouble: vectorOriginal];
    originConverted[ 0] = origin[ 0] * vectorOriginal[ 0] + origin[ 1] * vectorOriginal[ 1] + origin[ 2] * vectorOriginal[ 2];
    originConverted[ 1] = origin[ 0] * vectorOriginal[ 3] + origin[ 1] * vectorOriginal[ 4] + origin[ 2] * vectorOriginal[ 5];
    originConverted[ 2] = origin[ 0] * vectorOriginal[ 6] + origin[ 1] * vectorOriginal[ 7] + origin[ 2] * vectorOriginal[ 8];
    
    voxelSpacing[0] = [firstPix pixelSpacingX];
    voxelSpacing[1] = [firstPix pixelSpacingY];
    voxelSpacing[2] = [firstPix sliceInterval];
    
    importFilter->SetRegion(region);
    importFilter->SetOrigin(originConverted);
    importFilter->SetSpacing(voxelSpacing);
    importFilter->SetImportPointer([[self.volumeWindow viewerController] volumePtr] , bufferSize, false);// do not overwrite original data
    
    image = importFilter->GetOutput();
    image->Update();
    return image;
}

// slice in ITK
- (ImageTypeFloat2D::Pointer)WrapImageFloat2D
{
    long SliceIndex = [[[self.volumeWindow viewerController]imageView]curImage];
    
    ImageTypeFloat2D::Pointer wrapImage;
    ImportFilterTypeFloat2D::Pointer importFilter = ImportFilterTypeFloat2D::New();
    ImportFilterTypeFloat2D::SizeType size;
    ImportFilterTypeFloat2D::IndexType start;
    ImportFilterTypeFloat2D::RegionType region;
    
    DCMPix *firstPix = [[[self.volumeWindow viewerController] pixList] objectAtIndex:0];
    
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    
    long bufferSize = size[0] * size[1];
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    
    double voxelSpacing[3];
    double origin[3];
    origin[0] = [firstPix originX];
    origin[1] = [firstPix originY];
    voxelSpacing[0] = [firstPix pixelSpacingX];
    voxelSpacing[1] = [firstPix pixelSpacingY];
    
    importFilter->SetRegion(region);
    importFilter->SetSpacing(voxelSpacing);
    importFilter->SetImportPointer([[self.volumeWindow viewerController] volumePtr]+bufferSize*SliceIndex , bufferSize, false);// do not overwrite original data
    
    wrapImage = importFilter->GetOutput();
    wrapImage->Update();
    return wrapImage;
}

// mask of the myocardium
- (ImageTypeFloat2D::Pointer)imageMyocardium
{
    ImageTypeFloat2D::Pointer image2D = [self WrapImageFloat2D];
    ImageTypeFloat2D::Pointer myocardium2D = ImageTypeFloat2D::New();
    DCMPix *firstPix = [[[self.volumeWindow viewerController] pixList] objectAtIndex:0];
    ImageTypeFloat2D::SizeType size;
    ImageTypeFloat2D::IndexType start;
    ImageTypeFloat2D::RegionType region;
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    myocardium2D->SetRegions(region);
    myocardium2D->Allocate();
    myocardium2D->FillBuffer(0);
    OSIROI* outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];
    OSIROI* insideROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
    
    if (outsideROI && insideROI) {            
            OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
            OSIROIMask *outsideMask = [outsideROI ROIMaskForFloatVolumeData:floatVolumeData];
            OSIROIMask *insideMask = [insideROI ROIMaskForFloatVolumeData:floatVolumeData];
            OSIROIMask *myocardiumMask = [outsideMask ROIMaskBySubtractingMask:insideMask];
            NSArray *arrayMaskRuns = [myocardiumMask maskRuns];
            
            for (NSValue *value in arrayMaskRuns) {
                OSIROIMaskRun run;
                [value getValue:&run];
                NSRange range =  run.widthRange;
                for (int i = 0; i<range.length; i++) {
                    ImageTypeFloat2D::IndexType pixelIndex;
                    pixelIndex[0] = range.location+i;   // x position
                    pixelIndex[1] = run.heightIndex;   // y position
                    myocardium2D->SetPixel(pixelIndex, image2D->GetPixel(pixelIndex));
                }
            }
    }
    return myocardium2D;
}

// 2SD thresholding
- (ImageTypeInt3D::Pointer)sd
{
    typedef itk::JoinSeriesImageFilter<ImageTypeFloat2D, ImageTypeFloat3D> JoinSeriesImageFilterType;
    JoinSeriesImageFilterType::Pointer joinSeriesImageFilter = JoinSeriesImageFilterType::New();
    joinSeriesImageFilter->SetOrigin(0);
    joinSeriesImageFilter->SetSpacing(1);
    
    JoinSeriesImageFilterType::Pointer joinSeriesImageFilterMyo = JoinSeriesImageFilterType::New();
    joinSeriesImageFilterMyo->SetOrigin(0);
    joinSeriesImageFilterMyo->SetSpacing(1);
    
    ViewerController *viewerController = [self.volumeWindow viewerController];
    int curIndex = [[viewerController imageView]curImage];
    BOOL sliceIndex = [self slice];
    
    NSMutableArray  *roiSeriesList  = [viewerController roiList];
    
    if (sliceIndex)
    {
        for (int j=0; j<[roiSeriesList count]; j++) {
            [viewerController setImageIndex:j];
            ImageTypeFloat2D::Pointer image2D = [self imageMyocardium];
            joinSeriesImageFilterMyo->PushBackInput(image2D);
            OSIROI *outsideROI = [[self.volumeWindow ROIManager] firstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium"];
            meanHealthy = 0;
            sdHealthy = 0;
            if (outsideROI) {
                NSArray *epiNameComponents = [[outsideROI name] componentsSeparatedByString:@";"];
                for (NSString *component in epiNameComponents) {
                    
                    if ([component hasPrefix:@"HsuMean_"])
                        meanHealthy = [[component substringFromIndex:[@"HsuMean_" length]] floatValue];
                    if ([component hasPrefix:@"HsuStd_"])
                        sdHealthy = [[component substringFromIndex:[@"HsuStd_" length]] floatValue];
                }
                typedef itk::BinaryThresholdImageFilter<ImageTypeFloat2D,ImageTypeFloat2D> BinaryThresholdImageFilterType;
                BinaryThresholdImageFilterType::Pointer binaryThresholdImageFilter = BinaryThresholdImageFilterType::New();
                binaryThresholdImageFilter->SetInput(image2D);
                binaryThresholdImageFilter->SetLowerThreshold(0);
                binaryThresholdImageFilter->SetUpperThreshold(meanHealthy + 2*sdHealthy);
                binaryThresholdImageFilter->SetInsideValue(0);
                binaryThresholdImageFilter->SetOutsideValue(1);
                binaryThresholdImageFilter->Update();
                joinSeriesImageFilter->PushBackInput(binaryThresholdImageFilter->GetOutput());
            }
            else
                joinSeriesImageFilter->PushBackInput(image2D);
            
        }
        [viewerController setImageIndex:curIndex];
    }
    else
    {
        for (int j=[roiSeriesList count]-1; j>=0; j--) {
            [viewerController setImageIndex:j];
            ImageTypeFloat2D::Pointer image2D = [self imageMyocardium];
            joinSeriesImageFilterMyo->PushBackInput(image2D);
            OSIROI *outsideROI = [[self.volumeWindow ROIManager] firstVisibleROIWithNamePrefix:@"CMRSegTools: Epicardium"];
            meanHealthy = 0;
            sdHealthy = 0;
            if (outsideROI) {
                NSArray *epiNameComponents = [[outsideROI name] componentsSeparatedByString:@";"];
                for (NSString *component in epiNameComponents) {
                    
                    if ([component hasPrefix:@"HsuMean_"])
                        meanHealthy = [[component substringFromIndex:[@"HsuMean_" length]] floatValue];
                    if ([component hasPrefix:@"HsuStd_"])
                        sdHealthy = [[component substringFromIndex:[@"HsuStd_" length]] floatValue];
                }
                typedef itk::BinaryThresholdImageFilter<ImageTypeFloat2D,ImageTypeFloat2D> BinaryThresholdImageFilterType;
                BinaryThresholdImageFilterType::Pointer binaryThresholdImageFilter = BinaryThresholdImageFilterType::New();
                binaryThresholdImageFilter->SetInput(image2D);
                binaryThresholdImageFilter->SetLowerThreshold(0);
                binaryThresholdImageFilter->SetUpperThreshold(meanHealthy + 2*sdHealthy);
                binaryThresholdImageFilter->SetInsideValue(0);
                binaryThresholdImageFilter->SetOutsideValue(1);
                binaryThresholdImageFilter->Update();
                joinSeriesImageFilter->PushBackInput(binaryThresholdImageFilter->GetOutput());
            }
            else
                joinSeriesImageFilter->PushBackInput(image2D);
        }
        [viewerController setImageIndex:(int)[roiSeriesList count]-curIndex-1];
    }
    
    joinSeriesImageFilter->Update();
    joinSeriesImageFilterMyo->Update();
    imageMyo = joinSeriesImageFilterMyo->GetOutput();
    
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> CastImageFilterType;
    CastImageFilterType::Pointer castImageFilter = CastImageFilterType::New();
    castImageFilter->SetInput(joinSeriesImageFilter->GetOutput());
    castImageFilter->Update();
    
    typedef itk::ConnectedComponentImageFilter <ImageTypeInt3D, ImageTypeInt3D> ConnectedComponentImageFilterType;
    ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
    labelFilter->SetInput(castImageFilter->GetOutput());
    labelFilter->Update();
    return labelFilter->GetOutput();
}

// fwhm on each slice
- (ImageTypeInt3D::Pointer)fwhm:(ImageTypeInt3D::Pointer)mask
{
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> CastImageFilterType;
    CastImageFilterType::Pointer castImageFilter = CastImageFilterType::New();
    castImageFilter->SetInput(imageMyo);
    castImageFilter->Update();
    
    typedef itk::JoinSeriesImageFilter<ImageTypeInt2D, ImageTypeInt3D> JoinSeriesImageFilterType;
    JoinSeriesImageFilterType::Pointer joinSeriesImageFilter = JoinSeriesImageFilterType::New();
    joinSeriesImageFilter->SetOrigin(0);
    joinSeriesImageFilter->SetSpacing(1);
    
    for (int slice = 0; slice<castImageFilter->GetOutput()->GetLargestPossibleRegion().GetSize()[2]; slice++) {
        typedef itk::ExtractImageFilter< ImageTypeInt3D, ImageTypeInt2D > extractType;
        extractType::Pointer filter1 = extractType::New();
        extractType::Pointer filter2 = extractType::New();
        ImageTypeInt3D::RegionType inputRegion = castImageFilter->GetOutput()->GetLargestPossibleRegion();
        
        ImageTypeInt3D::SizeType size = inputRegion.GetSize();
        size[2] = 0;
        
        ImageTypeInt3D::IndexType start = inputRegion.GetIndex();
        start[2] = slice;
        
        ImageTypeInt3D::RegionType desiredRegion;
        desiredRegion.SetSize(  size  );
        desiredRegion.SetIndex( start );
        
        filter1->SetExtractionRegion( desiredRegion );
        filter1->SetInput( mask );
        filter1->SetDirectionCollapseToIdentity();
        filter1->Update();
        
        filter2->SetExtractionRegion( desiredRegion );
        filter2->SetInput( castImageFilter->GetOutput() );
        filter2->SetDirectionCollapseToIdentity();
        filter2->Update();
        
        typedef itk::BinaryThresholdImageFilter<ImageTypeInt2D,ImageTypeInt2D> BinaryThresholdImageFilterType;
        BinaryThresholdImageFilterType::Pointer binaryThresholdImageFilter = BinaryThresholdImageFilterType::New();
        binaryThresholdImageFilter->SetInput(filter1->GetOutput());
        binaryThresholdImageFilter->SetLowerThreshold(0);
        binaryThresholdImageFilter->SetUpperThreshold(0.1);
        binaryThresholdImageFilter->SetInsideValue(0);
        binaryThresholdImageFilter->SetOutsideValue(1);
        binaryThresholdImageFilter->Update();
        
        // to find the maximum of intensity under the myocardium
        typedef itk::LabelStatisticsImageFilter<ImageTypeInt2D, ImageTypeInt2D> LabelStatisticsImageFilterType;
        LabelStatisticsImageFilterType::Pointer labelStatisticsImageFilter = LabelStatisticsImageFilterType::New();
        labelStatisticsImageFilter->SetLabelInput( binaryThresholdImageFilter->GetOutput() );
        labelStatisticsImageFilter->SetInput(filter2->GetOutput());
        labelStatisticsImageFilter->Update();
        double max = 0;
        
        typedef LabelStatisticsImageFilterType::ValidLabelValuesContainerType ValidLabelValuesType;
        typedef LabelStatisticsImageFilterType::LabelPixelType                LabelPixelType;
        
        for(ValidLabelValuesType::const_iterator vIt=labelStatisticsImageFilter->GetValidLabelValues().begin();
            vIt != labelStatisticsImageFilter->GetValidLabelValues().end();
            ++vIt)
        {
            if ( labelStatisticsImageFilter->HasLabel(*vIt))
            {
                LabelPixelType labelValue = *vIt;
                if (labelValue !=0)
                    max = labelStatisticsImageFilter->GetMaximum( labelValue );
            }
        }
        
        // thresholding with a thresh max/2
        if (labelStatisticsImageFilter->GetNumberOfLabels() != 1) {
            typedef itk::MultiplyImageFilter<ImageTypeInt2D> multiplyType;
            multiplyType::Pointer multiply = multiplyType::New();
            multiply->SetInput1(filter2->GetOutput());
            multiply->SetInput2(binaryThresholdImageFilter->GetOutput());
            multiply->Update();
            
            binaryThresholdImageFilter->SetInput(multiply->GetOutput());
            binaryThresholdImageFilter->SetLowerThreshold(0);
            binaryThresholdImageFilter->SetUpperThreshold((max)/2);
            binaryThresholdImageFilter->SetInsideValue(0);
            binaryThresholdImageFilter->SetOutsideValue(1);
            binaryThresholdImageFilter->Update();
            
            joinSeriesImageFilter->PushBackInput(binaryThresholdImageFilter->GetOutput());
        }
        else
            joinSeriesImageFilter->PushBackInput(binaryThresholdImageFilter->GetOutput());
        
    }
    joinSeriesImageFilter->Update();
    typedef itk::ConnectedComponentImageFilter <ImageTypeInt3D, ImageTypeInt3D> ConnectedComponentImageFilterType;
    ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
    labelFilter->SetInput(joinSeriesImageFilter->GetOutput());
    labelFilter->Update();
    return labelFilter->GetOutput();
}

// mask of the endocardium in ITK
- (ImageTypeInt3D::Pointer)ComputeEndoContour
{
    ImageTypeInt3D::Pointer endoContour = ImageTypeInt3D::New();
    ImageTypeInt3D::SizeType size;
    ImageTypeInt3D::IndexType start;
    ImageTypeInt3D::RegionType region;
    
    DCMPix *firstPix = [[[self.volumeWindow viewerController] pixList] objectAtIndex:0];
    NSUInteger slices = [[[self.volumeWindow viewerController] pixList] count];
    
    //Size Width * Height * NoOfSlices
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    size[2] = slices;
    
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    endoContour->SetRegions(region);
    endoContour->Allocate();
    endoContour->FillBuffer(0);
    ImageTypeFloat3D::PixelType   pixelValue;
    pixelValue =  (float)255;
    
    NSMutableArray  *roiSeriesList = [[self.volumeWindow viewerController] roiList];
    for (int numSeries=0;numSeries<[roiSeriesList count]; numSeries++) {
        // All rois contained in the current image
        NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
        for (int numROI=0; numROI<[roiImageList count]; numROI++) {
            if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
                ROI *endoBaseROI = [roiImageList objectAtIndex:numROI];
                NSMutableArray  *pts = [endoBaseROI points];
                for (int numPts = 0; numPts < [pts count]; numPts++)
                {
                    MyPoint *point = [pts objectAtIndex:numPts];
                    ImageTypeFloat3D::IndexType pixelIndex;
                    pixelIndex[0] = point.x;   // x position
                    pixelIndex[1] = point.y;   // y position
                    pixelIndex[2] = numSeries;   // z position
                    endoContour->SetPixel(   pixelIndex,   pixelValue  );
                }
            }
        }
    }
    // connected component
    typedef itk::ConnectedComponentImageFilter <ImageTypeInt3D, ImageTypeInt3D> ConnectedComponentImageFilterType;
    ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
    labelFilter->SetInput(endoContour);
    labelFilter->Update();
    return(labelFilter->GetOutput());
}

// volume analysis
- (ImageTypeInt3D::Pointer)volumeFeature:(ImageTypeInt3D::Pointer)image
{
    // myocardium density = 1.055 g/cm3
    // remove all labels which have a mass < 0.1g
    typedef itk::RelabelComponentImageFilter<ImageTypeInt3D, ImageTypeInt3D> FilterType;
    FilterType::Pointer relabelFilter = FilterType::New();
    relabelFilter->SetInput( image );
    float minVolumeInMm3 = 0.1/(1.05*0.001);
    
    DCMPix *firstPix = [[[self.volumeWindow viewerController] pixList] objectAtIndex:0];
    float volumeOfPixelMm3 = [firstPix pixelSpacingX]*[firstPix pixelSpacingY]*[firstPix sliceInterval];
    int minsize = round( minVolumeInMm3/volumeOfPixelMm3 );
    relabelFilter->SetMinimumObjectSize( minsize );
    relabelFilter->Update();
    return(relabelFilter->GetOutput());
}

// intensity and distance analysis
- (ImageTypeInt3D::Pointer)intensityDistanceFeature:(ImageTypeInt3D::Pointer)img originalImage:(ImageTypeFloat3D::Pointer)OriginalImage endoMask:(ImageTypeInt3D::Pointer)endoMask
{
    typedef itk::LabelGeometryImageFilter< ImageTypeInt3D > LabelGeometryImageFilterType;
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
    labelGeometryImageFilter->SetInput( img );
    labelGeometryImageFilter->CalculatePixelIndicesOn();
    labelGeometryImageFilter->Update();
    LabelGeometryImageFilterType::LabelsType allLabels = labelGeometryImageFilter->GetLabels();
    LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt;
    
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilterEndo = LabelGeometryImageFilterType::New();
    labelGeometryImageFilterEndo->SetInput( endoMask );
    labelGeometryImageFilterEndo->CalculatePixelIndicesOn();
    labelGeometryImageFilterEndo->Update();
    LabelGeometryImageFilterType::LabelsType allLabelsEndo = labelGeometryImageFilterEndo->GetLabels();
    LabelGeometryImageFilterType::LabelsType::iterator allLabelsItEndo;
    
    DCMPix *firstPix = [[[self.volumeWindow viewerController] pixList] objectAtIndex:0];
    std::vector<float> intensityMean;
    float meanTotal = 0;
    int numPixelTotal = 0;
    std::vector<float> distance;
    int indexVector = 0;
    
    for( allLabelsIt = allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
    {
        float meanLabel = 0;
        int numPixelLabel = 0;
        distance.push_back(2);
        LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
        std::vector<LabelGeometryImageFilterType::LabelIndexType> vect = labelGeometryImageFilter->GetPixelIndices(labelValue);
        for( allLabelsItEndo = allLabelsEndo.begin()+1; allLabelsItEndo != allLabelsEndo.end(); allLabelsItEndo++ )
        {
            LabelGeometryImageFilterType::LabelPixelType labelValueEndo = *allLabelsItEndo;
            std::vector<LabelGeometryImageFilterType::LabelIndexType> indicesEndo = labelGeometryImageFilterEndo->GetPixelIndices(labelValueEndo);
            for (int i=0; i<vect.size(); i++) {
                ImageTypeFloat3D::IndexType pixelIndex;
                pixelIndex[0] = vect.at(i)[0];   // x position
                pixelIndex[1] = vect.at(i)[1];   // y position
                pixelIndex[2] = vect.at(i)[2];   // z position
                
                meanLabel += OriginalImage->GetPixel(pixelIndex);
                numPixelLabel += 1;
                meanTotal += OriginalImage->GetPixel(pixelIndex);
                numPixelTotal += 1;
                
                for (int j=0; j<indicesEndo.size(); j++) {
                    if (vect.at(i)[2]==indicesEndo.at(j)[2]) {
                        
                        itk::Point<float,3> p0;
                        p0[0] = vect.at(i)[0];
                        p0[1] = vect.at(i)[1];
                        p0[2] = vect.at(i)[2];
                        itk::Point<float,3> p1;
                        p1[0] = indicesEndo.at(j)[0];
                        p1[1] = indicesEndo.at(j)[1];
                        p1[2] = indicesEndo.at(j)[2];
                        
                        double dist = p0.EuclideanDistanceTo(p1);
                        if (dist/[firstPix pixelSpacingX]<distance.at(indexVector)) {
                            distance.at(indexVector) = dist/[firstPix pixelSpacingX];
                        }
                    }
                }
            }
        }
        intensityMean.push_back(meanLabel/numPixelLabel);
        indexVector +=1;
    }
    // remove all labels which have a mean intensity < 50% of total mean intensity and distance to endocardium > 2mm
    indexVector = 0;
    for( allLabelsIt = allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
    {
        LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
        std::vector<LabelGeometryImageFilterType::LabelIndexType> vect = labelGeometryImageFilter->GetPixelIndices(labelValue);
        if (intensityMean.at(indexVector)/(meanTotal/numPixelTotal)<0.5 || distance.at(indexVector)>=2) {
            for (int i=0; i<vect.size(); i++) {
                ImageTypeFloat3D::IndexType pixelIndex;
                pixelIndex[0] = vect.at(i)[0];   // x position
                pixelIndex[1] = vect.at(i)[1];   // y position
                pixelIndex[2] = vect.at(i)[2];   // z position
                img->SetPixel(pixelIndex, 0);
            }
        }
        indexVector+=1;
    }
    return img;
}

// compute the OSIMaskROI of the binary image on each slice
- (void)MaskAfterFeatureAnalysis:(ImageTypeInt3D::Pointer)image :(NSString*)name :(int)slice
{
    DCMPix *firstPix = [[[self.volumeWindow viewerController] pixList] objectAtIndex:0];
        
    NSMutableArray *infarctArray  = [[[NSMutableArray alloc] init] autorelease];

    for (int h = 0; h<[firstPix pheight]; h++) {
        for (int w=(int)[firstPix pwidth]-1; w>=0; w--) {
            ImageTypeFloat3D::IndexType pixelIndex;
            pixelIndex[0] = w;   // x position
            pixelIndex[1] = h;   // y position
            pixelIndex[2] = slice;   // z position
            
            if (abs(image->GetPixel(pixelIndex))>0) {
                NSRange width = NSMakeRange(w, 1);
                OSIROIMaskRun run;
                run.widthRange = width;
                run.heightIndex = h;
                run.depthIndex = slice;
                run.intensity = 255;
                NSValue *miValue = [NSValue value: &run withObjCType:@encode(OSIROIMaskRun)];
                [infarctArray addObject:miValue];
            }
        }
    }
    OSIROIMask *Mask = [[[OSIROIMask alloc] initWithMaskRuns:infarctArray] autorelease];
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    OSIMaskROI *Roi =  [[[OSIMaskROI alloc] initWithROIMask:Mask homeFloatVolumeData:floatVolumeData name:name] autorelease];
    [[self.volumeWindow ROIManager]addROI:Roi];
}

// hole filling
- (ImageTypeInt3D::Pointer)Close:(ImageTypeInt3D::Pointer)image :(ImageTypeInt3D::Pointer)endo
{
    // binary image
    typedef itk::BinaryThresholdImageFilter <ImageTypeInt3D, ImageTypeInt3D> BinaryThresholdImageFilterType;
    BinaryThresholdImageFilterType::Pointer thresholdFilter = BinaryThresholdImageFilterType::New();
    thresholdFilter->SetInput(image);
    thresholdFilter->SetLowerThreshold(0);
    thresholdFilter->SetUpperThreshold(0.1);
    thresholdFilter->SetInsideValue(0);
    thresholdFilter->SetOutsideValue(1);
    thresholdFilter->Update();
    
    // fill the hole
    typedef itk::VotingBinaryIterativeHoleFillingImageFilter<ImageTypeInt3D > FilterType;
    FilterType::Pointer filter = FilterType::New();
    ImageTypeInt3D::SizeType indexRadius;
    indexRadius[0] = 2; // radius along x
    indexRadius[1] = 2; // radius along y
    indexRadius[2] = 0; // radius along y
    filter->SetRadius( indexRadius );
    filter->SetBackgroundValue( 0 );
    filter->SetForegroundValue( 1 );
    filter->SetMajorityThreshold( 3 );
    filter->SetMaximumNumberOfIterations( 100 );
    filter->SetInput( thresholdFilter->GetOutput() );
    filter->Update();
    
    // subtract image with hole filling to binary image : we obtain an image with only hole.
    typedef itk::SubtractImageFilter <ImageTypeInt3D, ImageTypeInt3D > SubtractImageFilterType;
    SubtractImageFilterType::Pointer subtractFilter = SubtractImageFilterType::New ();
    subtractFilter->SetInput1(filter->GetOutput());
    subtractFilter->SetInput2(thresholdFilter->GetOutput());
    subtractFilter->Update();

    return subtractFilter->GetOutput();
}

// image defined anterior -> posterior or left->right
- (BOOL)slice
{
    ViewerController *viewerController = [self.volumeWindow viewerController];
    int curIndex = [[viewerController imageView]curImage];
    NSString        *dicomTag = @"0020,0013";
    NSArray         *pixList = [viewerController  pixList: 0];
    DCMPix          *curPix = [pixList objectAtIndex: curIndex];
    NSString        *file_path = [curPix sourceFile];
    DCMObject       *dcmObj = [DCMObject objectWithContentsOfFile:file_path decodingPixelData:NO];
    DCMAttributeTag *tag = [DCMAttributeTag tagWithName:dicomTag];
    if (!tag) tag = [DCMAttributeTag tagWithTagString:dicomTag];
    NSString        *val;
    DCMAttribute    *attr;
    attr = [dcmObj attributeForTag:tag];
    val = [[attr value] description];
    int valint=[[[NSString alloc] initWithString:val] intValue];
    BOOL rep;
    if (curIndex+1==valint) {
        rep = true;
    }
    else
        rep = false;
    
    return rep;
}

- (void)compute
{
    // stack in ITK space :
    ImageTypeFloat3D::Pointer image3D = [self WrapImageFloat3D];
    // for each image : 2SD thresholding
    ImageTypeInt3D::Pointer imageInfarcted3DStd = [self sd];
    // mask of the endocardium (needed for the distance analysis)
    ImageTypeInt3D::Pointer imageMask3D = [self ComputeEndoContour];
    // result of the volume analysis
    ImageTypeInt3D::Pointer maskAfterVolumeAnalysisStd =[self volumeFeature:imageInfarcted3DStd];
    // result of the distance and intensity analysis
    ImageTypeInt3D::Pointer maskAfterIntensityDistanceAnalysisStd =[self intensityDistanceFeature:maskAfterVolumeAnalysisStd originalImage:image3D endoMask:imageMask3D];
    // apply, after feature analysis, on each image, a FWHM Max thresholding
    ImageTypeInt3D::Pointer imageInfarcted3DFWHM = [self fwhm:maskAfterIntensityDistanceAnalysisStd];
    // volume analysis
    ImageTypeInt3D::Pointer maskAfterVolumeAnalysisFWHM =[self volumeFeature:imageInfarcted3DFWHM];
    // intensity and distance analysis
    ImageTypeInt3D::Pointer maskAfterIntensityDistanceAnalysisFWHM =[self intensityDistanceFeature:maskAfterVolumeAnalysisFWHM originalImage:image3D endoMask:imageMask3D];
    // fill the hole to obtain no reflow
    ImageTypeInt3D::Pointer noReflow =[self Close:maskAfterIntensityDistanceAnalysisFWHM :imageMask3D];
    
    // browse through the images to add on each image the OSIROI of infarct and no reflow
    ViewerController *viewerController = [self.volumeWindow viewerController];
    int curIndex = [[viewerController imageView]curImage];
    BOOL sliceIndex = [self slice];
    NSMutableArray  *roiSeriesList  = [viewerController roiList];
    
    for (int j=0; j<[roiSeriesList count]; j++) {
        [viewerController setImageIndex:j];
        [self MaskAfterFeatureAnalysis:maskAfterIntensityDistanceAnalysisFWHM :@"Hsu" :j];
        [self MaskAfterFeatureAnalysis:noReflow :@"Hsu: No-reflow;no" :j];
        [viewerController setImageIndex:j];
    }
    if (sliceIndex)
        [viewerController setImageIndex:curIndex];
    else
    {
        for (int j=0; j<[roiSeriesList count]; j++) {
            [viewerController setImageIndex:j];
        }
        [viewerController setImageIndex:(int)[roiSeriesList count]-curIndex-1];
    }
}
@end
