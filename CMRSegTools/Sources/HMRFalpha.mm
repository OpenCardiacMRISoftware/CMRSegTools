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
//  HMRFalpha.m
//  CMRSegTools
//
//  Created by Coralie Vandroux on 8/14/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "HMRFalpha.h"
#ifdef DEBUG_HMRF_alpha
#include <stdlib.h>
#include <stdio.h>
//    char mychar[255] ;
//    FILE* fichier;
//    FILE* fichier1;
#endif

#include <numeric>

#define IT_MAP 20
#define IT_EM 10

@interface HMRFalpha ()
@property (nonatomic, readwrite, retain) OSIVolumeWindow *volumeWindow;
@end

@implementation HMRFalpha

@synthesize volumeWindow = _volumeWindow;

// initialization
- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow
{
    self.volumeWindow = volumeWindow;
    _image = ImageTypeFloat3D::New();
    _myocardium = ImageTypeInt3D::New();
    _myocardiumPolar = ImageTypeFloat3D::New();
    _label = ImageTypeFloat3D::New();
    _labelCart = ImageTypeFloat3D::New();
    _noReflowCart = ImageTypeFloat3D::New();
    _viewControl=[self.volumeWindow viewerController];
    return self;
}

// current image in ITK space :
- (ImageTypeFloat2D::Pointer)WrapImageFloat2D
{
    long SliceIndex = [[_viewControl imageView]curImage];
    
    ImageTypeFloat2D::Pointer wrapImage;
    ImportFilterTypeFloat2D::Pointer importFilter = ImportFilterTypeFloat2D::New();
    ImportFilterTypeFloat2D::SizeType size;
    ImportFilterTypeFloat2D::IndexType start;
    ImportFilterTypeFloat2D::RegionType region;
    
    DCMPix *firstPix = [[_viewControl pixList] objectAtIndex:0];
    
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
    importFilter->SetImportPointer([_viewControl volumePtr]+bufferSize*SliceIndex , bufferSize, false);// do not overwrite original data
    
    wrapImage = importFilter->GetOutput();
    wrapImage->Update();
    return wrapImage;
}

// image 3D in polar coordinates
- (void)imagePolar
{
    // initialize myocardium mask :
    _myocardium = ImageTypeInt3D::New();
    DCMPix *firstPix = [[_viewControl pixList] objectAtIndex:0];
    NSUInteger slices = [[_viewControl pixList] count];
    ImageTypeInt3D::SizeType size;
    ImageTypeInt3D::IndexType start;
    ImageTypeInt3D::RegionType region;
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    size[2] = slices;
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    _myocardium->SetRegions(region);
    _myocardium->Allocate();
    _myocardium->FillBuffer(0);
    
    typedef itk::JoinSeriesImageFilter<ImageTypeFloat2D, ImageTypeFloat3D> JoinSeriesImageFilterType;
    JoinSeriesImageFilterType::Pointer joinSeriesImageFilter1 = JoinSeriesImageFilterType::New();
    joinSeriesImageFilter1->SetOrigin(0);
    joinSeriesImageFilter1->SetSpacing(1);
    JoinSeriesImageFilterType::Pointer joinSeriesImageFilter2 = JoinSeriesImageFilterType::New();
    joinSeriesImageFilter2->SetOrigin(0);
    joinSeriesImageFilter2->SetSpacing(1);
    JoinSeriesImageFilterType::Pointer joinSeriesImageFilter3 = JoinSeriesImageFilterType::New();
    joinSeriesImageFilter3->SetOrigin(0);
    joinSeriesImageFilter3->SetSpacing(1);
    
    // center of myocardium and epicardium ray
    [self centerRay];
    
    int curIndex = [[_viewControl imageView]curImage];
    BOOL sliceIndex = [self slice];
    std::vector<double> meanVector1,meanVector2,stdVector1,stdVector2;
    NSMutableArray  *roiSeriesList  = [_viewControl roiList];
    // if image is defined anterior -> posterior or right -> left
    if (sliceIndex) {
        for (int j=0; j<[roiSeriesList count]; j++) { // for all slices
            [_viewControl setImageIndex:j];
            ImageTypeFloat2D::Pointer imagePolar2D = [self cartesian2polar]; // image in polar coordinates
            joinSeriesImageFilter1->PushBackInput(imagePolar2D);
            
            double m1,m2,s1,s2;
            ImageTypeFloat2D::Pointer myocardium2D = [self initParam:&m1 :&m2 :&s1 :&s2];
            ImageTypeFloat2D::Pointer myocardiumPolar2D = [self cartesian2polarMyo:myocardium2D]; // myocardium mask in polar coordinates
            joinSeriesImageFilter3->PushBackInput(myocardiumPolar2D);
            meanVector1.push_back(m1);
            meanVector2.push_back(m2);
            stdVector1.push_back(s1);
            stdVector2.push_back(s2);
            
            ImageTypeFloat2D::Pointer labelPolar2D = [self threshold:imagePolar2D]; // initial label image
            joinSeriesImageFilter2->PushBackInput(labelPolar2D);
        }
        [_viewControl setImageIndex:curIndex];        [_viewControl setImageIndex:curIndex];
    }
    else
    {
        for (int j=[roiSeriesList count]-1; j>=0; j--) { // for all slices
            [_viewControl setImageIndex:j];
            ImageTypeFloat2D::Pointer imagePolar2D = [self cartesian2polar]; // image in polar coordinates
            joinSeriesImageFilter1->PushBackInput(imagePolar2D);
            
            double m1,m2,s1,s2;
            ImageTypeFloat2D::Pointer myocardium2D = [self initParam:&m1 :&m2 :&s1 :&s2];
            ImageTypeFloat2D::Pointer myocardiumPolar2D = [self cartesian2polarMyo:myocardium2D]; // myocardium mask in polar coordinates
            joinSeriesImageFilter3->PushBackInput(myocardiumPolar2D);
            meanVector1.push_back(m1);
            meanVector2.push_back(m2);
            stdVector1.push_back(s1);
            stdVector2.push_back(s2);
            
            ImageTypeFloat2D::Pointer labelPolar2D = [self threshold:imagePolar2D]; // initial label image
            joinSeriesImageFilter2->PushBackInput(labelPolar2D);
        }
        [_viewControl setImageIndex:(int)[roiSeriesList count]-curIndex-1];
    }
    joinSeriesImageFilter1->Update();
    joinSeriesImageFilter2->Update();
    joinSeriesImageFilter3->Update();
    _mean1 = std::accumulate(meanVector1.begin(), meanVector1.end(), 0)/meanVector1.size();
    _mean2 = std::accumulate(meanVector2.begin(), meanVector2.end(), 0)/meanVector2.size();
    _std1 = std::accumulate(stdVector1.begin(), stdVector1.end(), 0)/stdVector1.size();
    _std2 = std::accumulate(stdVector2.begin(), stdVector2.end(), 0)/stdVector2.size();
    
    _image = joinSeriesImageFilter1->GetOutput();
    _label = joinSeriesImageFilter2->GetOutput();
    _myocardiumPolar = joinSeriesImageFilter3->GetOutput();
    
}

// thresholding to obtain the initial label image with a thresh 4*max / 5
- (ImageTypeFloat2D::Pointer)threshold:(ImageTypeFloat2D::Pointer)imagePolar2D
{
    typedef itk::BinaryThresholdImageFilter<ImageTypeFloat2D,ImageTypeFloat2D> BinaryThresholdImageFilterType;
    BinaryThresholdImageFilterType::Pointer binaryThresholdImageFilter = BinaryThresholdImageFilterType::New();
    binaryThresholdImageFilter->SetInput(imagePolar2D);
    binaryThresholdImageFilter->SetLowerThreshold(0);
    binaryThresholdImageFilter->SetUpperThreshold(4*_maxMyocardium/5);
    binaryThresholdImageFilter->SetInsideValue(0);
    binaryThresholdImageFilter->SetOutsideValue(1);
    binaryThresholdImageFilter->Update();
    return binaryThresholdImageFilter->GetOutput();
}

// image in cartesian coordinates to polar coordinates
- (ImageTypeFloat2D::Pointer)cartesian2polar
{
    ImageTypeFloat2D::Pointer image2D = [self WrapImageFloat2D];
    ImageTypeFloat2D::Pointer imagePolar2D = ImageTypeFloat2D::New();
    ImageTypeFloat2D::SizeType size = image2D->GetLargestPossibleRegion().GetSize();
    
    //new image : we work only on the myocardium :
    ImageTypeFloat2D::SizeType newSize;
    ImageTypeFloat2D::IndexType start;
    ImageTypeFloat2D::RegionType region;
    newSize[0] = 360;
    newSize[1] = _ray;
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(newSize);
    imagePolar2D->SetRegions(region);
    imagePolar2D->Allocate();
    imagePolar2D->FillBuffer(0);
    
    itk::ImageRegionConstIterator<ImageTypeFloat2D> it(imagePolar2D,region);
    it.GoToBegin();
    while (!it.IsAtEnd()) {
        ImageTypeFloat2D::IndexType index = it.GetIndex();
        double thetaRad = M_PI*index[0]/180;
        double x = index[1]*cos(thetaRad) + _center.x;
        double y = -index[1]*sin(thetaRad) +_center.y;
        double v = fabs(floor(x)-x);
        double u = fabs(floor(y)-y);
        if (x>=0 && y>=0 && x<size[0] && y<size[1]) {
            // interpolation
            ImageTypeFloat2D::IndexType indexCart = it.GetIndex();
            indexCart[0] = floor(x);
            indexCart[1] = floor(y)+1;
            double A = image2D->GetPixel(indexCart);
            indexCart[0] = floor(x)+1;
            indexCart[1] = floor(y)+1;
            double B = image2D->GetPixel(indexCart);
            indexCart[0] = floor(x)+1;
            indexCart[1] = floor(y);
            double C = image2D->GetPixel(indexCart);
            indexCart[0] = floor(x);
            indexCart[1] = floor(y);
            double D = image2D->GetPixel(indexCart);
            imagePolar2D->SetPixel(index, u*(1-v)*A + u*v*B + v*(1-u)*C + (1-u)*(1-v)*D);
        }
        ++it;
    }
    return imagePolar2D;
}

// myocardium mask in cartesian coordinates to polar coordinates
- (ImageTypeFloat2D::Pointer)cartesian2polarMyo:(ImageTypeFloat2D::Pointer)img
{
    ImageTypeFloat2D::Pointer imagePolar2D = ImageTypeFloat2D::New();
    ImageTypeFloat2D::SizeType size = img->GetLargestPossibleRegion().GetSize();
    
    ImageTypeFloat2D::SizeType newSize;
    ImageTypeFloat2D::IndexType start;
    ImageTypeFloat2D::RegionType region;
    newSize[0] = 360;
    newSize[1] = _ray;
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(newSize);
    imagePolar2D->SetRegions(region);
    imagePolar2D->Allocate();
    imagePolar2D->FillBuffer(0);
    
    itk::ImageRegionConstIterator<ImageTypeFloat2D> it(imagePolar2D,region);
    it.GoToBegin();
    while (!it.IsAtEnd()) {
        ImageTypeFloat2D::IndexType index = it.GetIndex();
        double thetaRad = M_PI*index[0]/180;
        double x = index[1]*cos(thetaRad) + _center.x;
        double y = -index[1]*sin(thetaRad) +_center.y;
        double v = fabs(floor(x)-x);
        double u = fabs(floor(y)-y);
        // interpolation
        if (x>=0 && y>=0 && x<size[0] && y<size[1]) {
            ImageTypeFloat2D::IndexType indexCart = it.GetIndex();
            indexCart[0] = floor(x);
            indexCart[1] = floor(y)+1;
            double A = img->GetPixel(indexCart);
            indexCart[0] = floor(x)+1;
            indexCart[1] = floor(y)+1;
            double B = img->GetPixel(indexCart);
            indexCart[0] = floor(x)+1;
            indexCart[1] = floor(y);
            double C = img->GetPixel(indexCart);
            indexCart[0] = floor(x);
            indexCart[1] = floor(y);
            double D = img->GetPixel(indexCart);
            imagePolar2D->SetPixel(index, u*(1-v)*A + u*v*B + v*(1-u)*C + (1-u)*(1-v)*D);
        }
        ++it;
    }
    
    typedef itk::BinaryThresholdImageFilter <ImageTypeFloat2D, ImageTypeFloat2D> BinaryThresholdImageFilterType;
    BinaryThresholdImageFilterType::Pointer thresholdFilter = BinaryThresholdImageFilterType::New();
    thresholdFilter->SetInput(imagePolar2D);
    thresholdFilter->SetLowerThreshold(0);
    thresholdFilter->SetUpperThreshold(0.5);
    thresholdFilter->SetInsideValue(0);
    thresholdFilter->SetOutsideValue(1);
    thresholdFilter->Update();
    
    return thresholdFilter->GetOutput();
}

// compute the center of mass of Epicardium and endocardium
- (void)centerRay
{
    DCMView *view = [_viewControl imageView];
    DCMPix *pix = [view curDCM];
    double pixelSpacingX = [pix pixelSpacingX];
    
    std::vector<double> x;
    std::vector<double> y;
    std::vector<double> r;
    NSArray* ROIsOutside = [[self.volumeWindow ROIManager]ROIsWithName:@"CMRSegTools: Epicardium"];
    NSArray* ROIsInside = [[self.volumeWindow ROIManager]ROIsWithName:@"CMRSegTools: Endocardium"];
    for (OSIROI* outsideROI in ROIsOutside) {
        ROI* outsideBaseROI = [[outsideROI osiriXROIs]anyObject];
        NSPoint centerOutside = [outsideBaseROI centroid];
        x.push_back(centerOutside.x);
        y.push_back(centerOutside.y);
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        double outsideAreaCm = [outsideBaseROI roiArea];
#pragma clang diagnostic pop
        double outsideRadiusCm = sqrt(outsideAreaCm/M_PI);
        double outsideRadiusMm = outsideRadiusCm * 10.0;
        r.push_back(outsideRadiusMm/pixelSpacingX);
    }
    for (OSIROI* insideROI in ROIsInside) {
        ROI* insideBaseROI = [[insideROI osiriXROIs]anyObject];
        NSPoint centerInside = [insideBaseROI centroid];
        x.push_back(centerInside.x);
        y.push_back(centerInside.y);
    }
    _ray = floor(*std::max_element(r.begin(), r.end()) + 10);
    _center.x = std::accumulate(x.begin(), x.end(), 0)/x.size();
    _center.y = std::accumulate(y.begin(), y.end(), 0)/y.size();
}

// compute myocardium mask in cartesian coordinates and initial parameters.
- (ImageTypeFloat2D::Pointer)initParam:(double*)m1 :(double*)m2 :(double*)s1 :(double*)s2
{
    ImageTypeFloat2D::Pointer myocardium2D = ImageTypeFloat2D::New();
    DCMPix *firstPix = [[_viewControl pixList] objectAtIndex:0];
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
    
    OSIROI* outsideROI = [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"];
    OSIROI* insideROI = [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"];
    
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
                pixelIndex[1] = run.heightIndex;    // y position
                myocardium2D->SetPixel(pixelIndex, 1);
                
                ImageTypeFloat3D::IndexType pixelIndex3D;
                pixelIndex3D[0] = range.location+i;   // x position
                pixelIndex3D[1] = run.heightIndex;    // y position
                pixelIndex3D[2] = run.depthIndex;     // z position
                _myocardium->SetPixel(pixelIndex3D, 1);
            }
            
        }
        OSIMaskROI *myocardiumROI = [[[OSIMaskROI alloc] initWithROIMask:myocardiumMask homeFloatVolumeData:floatVolumeData name:@"myocardium"] autorelease];
        OSIROIFloatPixelData *floatPixelData = [myocardiumROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData];
        _maxMyocardium = [floatPixelData intensityMax];
        NSPredicate *thresholdPredicate = [NSPredicate predicateWithFormat:@"self.intensity >= %f", _maxMyocardium/2];
        OSIROIMask *thresholdMask = [[myocardiumMask filteredROIMaskUsingPredicate:thresholdPredicate floatVolumeData:floatVolumeData]autorelease];
        OSIROIMask *normalMask = [[myocardiumMask ROIMaskBySubtractingMask:thresholdMask]autorelease];
        OSIMaskROI *thresholdROI = [[[OSIMaskROI alloc] initWithROIMask:thresholdMask homeFloatVolumeData:floatVolumeData name:@"threshold"] autorelease];
        OSIMaskROI *normalROI = [[[OSIMaskROI alloc] initWithROIMask:normalMask homeFloatVolumeData:floatVolumeData name:@"normal"] autorelease];
        OSIROIFloatPixelData *floatPixelDataThreshold = [thresholdROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData];
        *m2 = [floatPixelDataThreshold intensityMean];
        *s2 = [floatPixelDataThreshold intensityStandardDeviation];
        OSIROIFloatPixelData *floatPixelDataNormal = [normalROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData];///
        *m1 = [floatPixelDataNormal intensityMean];
        *s1 = [floatPixelDataNormal intensityStandardDeviation];
        [arrayMaskRuns dealloc];
        
        //[floatPixelDataNormal release];
        //[floatPixelDataThreshold release];
    }
    return myocardium2D;
}

// get the pixels that surround the infarct label
- (std::vector<LabelGeometryImageFilterType::LabelIndexType>)regionGrowing
{
    typedef itk::BinaryContourImageFilter<ImageTypeFloat3D, ImageTypeFloat3D> BinaryContourImageFilterType;
    BinaryContourImageFilterType::Pointer binaryContourImageFilter = BinaryContourImageFilterType::New();
    binaryContourImageFilter->SetInput(_label);
    binaryContourImageFilter->SetForegroundValue(0);
    binaryContourImageFilter->SetBackgroundValue(1);
    binaryContourImageFilter->Update();
    
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> CastImageFilterType;
    CastImageFilterType::Pointer castImageFilter = CastImageFilterType::New();
    castImageFilter->SetInput(binaryContourImageFilter->GetOutput());
    castImageFilter->Update();
    
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
    labelGeometryImageFilter->SetInput( castImageFilter->GetOutput() );
    labelGeometryImageFilter->CalculatePixelIndicesOn();
    labelGeometryImageFilter->Update();
    LabelGeometryImageFilterType::LabelsType allLabels = labelGeometryImageFilter->GetLabels();
    LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt;
    
    std::vector<LabelGeometryImageFilterType::LabelIndexType> vect;
    for( allLabelsIt = allLabels.begin(); allLabelsIt != allLabels.end(); allLabelsIt++ )
    {
        LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
        if (labelValue==0) {
            vect = labelGeometryImageFilter->GetPixelIndices(labelValue);
        }
    }
    return vect;
}

// MAP algorithm
- (void)MAP
{
    std::vector<double> sum_U_MAP;
    for (int i=0; i < IT_MAP; i++) {
        ImageTypeFloat3D::Pointer copyLabel = _label;
        std::vector<LabelGeometryImageFilterType::LabelIndexType> contour = [self regionGrowing];
        sum_U_MAP.push_back(0);
        // for all bordering pixels
        for (int j=0; j<contour.size(); j++) {
            // likelihood energy for label 0 and label 1
            double y0 = _image->GetPixel(contour.at(j)) - _mean1;
            double y1 = _image->GetPixel(contour.at(j)) - _mean2;
            double U1_0 = y0*y0 / (2*_std1*_std1);
            double U1_1 = y1*y1 / (2*_std2*_std2);
            U1_0 = U1_0 + log(_std1);
            U1_1 = U1_1 + log(_std2);
            
            // prior energy for label 0 and label 1
            double U2_0 = [self clique:0 :contour.at(j)];
            double U2_1 = [self clique:1 :contour.at(j)];
            
            // sum of likelihood and prior energy for label 0 and label 1
            double U_0 = U1_0 + U2_0;
            double U_1 = U1_1 + U2_1;
            
            double x,val;
            if (U_0<U_1) {
                x = 0;
                val = U_0;
            }
            else {
                x = 1;
                val = U_1;
            }
            sum_U_MAP.at(i) = sum_U_MAP.at(i) + val;
            copyLabel->SetPixel(contour.at(j), x);
        }
        // if it converges, stop the loop
        _U = sum_U_MAP.at(i);
        _label = copyLabel;
        if (i>=3) {
            std::vector<double> tempVector;
            tempVector.push_back(sum_U_MAP.at(i-2));
            tempVector.push_back(sum_U_MAP.at(i-1));
            tempVector.push_back(sum_U_MAP.at(i));
            double mean = std::accumulate(tempVector.begin(), tempVector.end(), 0)/tempVector.size();
            std::vector<double> zero_mean(tempVector);
            std::transform(zero_mean.begin(), zero_mean.end(), zero_mean.begin(), std::bind2nd(std::minus<float>(), mean));
            double sq_sum = std::inner_product(zero_mean.begin(), zero_mean.end(), zero_mean.begin(), 0);
            double std = std::sqrt(sq_sum/(tempVector.size()-1));
            if (std/sum_U_MAP.at(i)<0.0001) {
                break;
            }
        }
        
#ifdef DEBUG_HMRF_alpha
        // This is an example, How to print out messages on the terminal:
        //snprintf(mychar,sizeof(mychar),"ITMAPalpha %d/%d\n",i,itMAP) ;
        //puts(mychar);
#endif
    }
}

// clique potential
- (double)clique:(double)l :(LabelGeometryImageFilterType::LabelIndexType)index
{
    ImageTypeFloat3D::SizeType size = _label->GetLargestPossibleRegion().GetSize();
    ImageTypeFloat3D::IndexType newIndex = index;
    double u2 = 0;
    
    if (index[0]-1>=0) {
        newIndex[0] = index[0]-1;
        if (l!=_label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    newIndex = index;
    if (index[0]+1<360) {
        newIndex[0] = index[0]+1;
        if (l!=_label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    newIndex = index;
    if (index[1]-1>=0) {
        newIndex[1] = index[1]-1;
        if (l!=_label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    newIndex = index;
    if (index[1]+1<_ray) {
        newIndex[1] = index[1]+1;
        if (l!=_label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    newIndex = index;
    if (index[2]-1>=0) {
        newIndex[2] = index[2]-1;
        if (l!=_label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    newIndex = index;
    if (index[2]+1<size[2]) {
        newIndex[2] = index[2]+1;
        if (l!=_label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    return u2;
}

// E Step : evaluate expectation
- (void)EStep
{
    [self MAP];
    _sumPly_0 = 0;
    _sumPly_1 = 0;
    _sumPlyY_0 = 0;
    _sumPlyY_1 = 0;
    _sumPlyYmu_0 = 0;
    _sumPlyYmu_1 = 0;
    _imageVector.erase(_imageVector.begin(), _imageVector.end());
    _ply_0.erase(_ply_0.begin(), _ply_0.end());
    _ply_1.erase(_ply_1.begin(), _ply_1.end());
    
    // for all pixels in the image space
    itk::ImageRegionConstIterator<ImageTypeFloat3D> it(_image,_image->GetRequestedRegion());
    it.GoToBegin();
    while (!it.IsAtEnd()) {
        double temp1_0 = 1/sqrt(2*M_PI*_std1*_std1) * exp(-(_image->GetPixel(it.GetIndex())-_mean1)*(_image->GetPixel(it.GetIndex())-_mean1) / (2 * _std1 * _std1));
        double temp1_1 = 1/sqrt(2*M_PI*_std2*_std2) * exp(-(_image->GetPixel(it.GetIndex())-_mean2)*(_image->GetPixel(it.GetIndex())-_mean2) / (2 * _std2 * _std2));
        
        double temp2_0 = [self clique:0 :it.GetIndex()];
        double temp2_1 = [self clique:1 :it.GetIndex()];
        
        _ply_0.push_back(temp1_0 * exp(-temp2_0));
        _ply_1.push_back(temp1_1 * exp(-temp2_1));
        double temp3 = _ply_0.back() + _ply_1.back();
        _ply_0.back() = _ply_0.back() / temp3;
        _ply_1.back() = _ply_1.back() / temp3;
        
        //  sum of posterior distribution for label 0 and label 1
        _sumPly_0 += _ply_0.back();
        _sumPly_1 += _ply_1.back();
        
        // sum of (posterior distribution * image pixel) for label 0 and 1
        _sumPlyY_0 += _ply_0.back() * _image->GetPixel(it.GetIndex());
        _sumPlyY_1 += _ply_1.back() * _image->GetPixel(it.GetIndex());
        
        _imageVector.push_back(_image->GetPixel(it.GetIndex()));
        ++it;
    }
}

// M Step : update parameters
- (void)MStep
{
    _mean1 = _sumPlyY_0/_sumPly_0;
    _mean2 = _sumPlyY_1/_sumPly_1;
    
    for (int i = 0; i<_ply_0.size(); i++) {
        _sumPlyYmu_0 += _ply_0.at(i) * (_imageVector.at(i)-_mean1) * (_imageVector.at(i)-_mean1);
        _sumPlyYmu_1 += _ply_1.at(i) * (_imageVector.at(i)-_mean2) * (_imageVector.at(i)-_mean2);
    }
    _std1 = sqrt(_sumPlyYmu_0/_sumPly_0);
    _std2 = sqrt(_sumPlyYmu_1/_sumPly_1);
}

// EM algorithm
- (void)EM
{
    typedef itk::MultiplyImageFilter<ImageTypeFloat3D> multiplyType;
    multiplyType::Pointer multiply = multiplyType::New();
    multiply->SetInput1(_label);
    multiply->SetInput2(_myocardiumPolar);
    multiply->Update();
    
    _label = multiply->GetOutput();
    
    std::vector<double> sum_U;
    for (int i=0; i<IT_EM; i++) {
        
        // This is an example, How to print out messages on the console
        //NSLog(@"[EM]: itEM value for iteration %d:  %d", i, itEM);
        
        [self EStep];
        [self MStep];
        // if it converges, stop the loop
        sum_U.push_back(_U);
        if (i>=3) {
            std::vector<double> tempVector;
            tempVector.push_back(sum_U.at(i-2));
            tempVector.push_back(sum_U.at(i-1));
            tempVector.push_back(sum_U.at(i));
            double mean = std::accumulate(tempVector.begin(), tempVector.end(), 0)/tempVector.size();
            std::vector<double> zero_mean(tempVector);
            std::transform(zero_mean.begin(), zero_mean.end(), zero_mean.begin(), std::bind2nd(std::minus<float>(), mean));
            double sq_sum = std::inner_product(zero_mean.begin(), zero_mean.end(), zero_mean.begin(), 0);
            double std = std::sqrt(sq_sum/(tempVector.size()-1));
            if (std/sum_U.at(i)<0.0001) {
                break;
            }
        }
        // This is an example, How to print out messages on the terminal:
        //snprintf(mychar,sizeof(mychar),"ITEMalpha %d/%d\n",i,itEM) ;
        //puts(mychar);
    }
}

// get the OSIROIMask of the mask in ITK
-(void) Mask3D:(ImageTypeFloat3D::Pointer)img :(NSString*)name
{
    ImageTypeFloat3D::SizeType size = img->GetLargestPossibleRegion().GetSize();
    NSMutableArray *Array  = [[[NSMutableArray alloc] init] autorelease];
    ImageTypeFloat3D::IndexType pixelIndex;
    for (int h = 0; h<size[1]; h++) {
        for (int w=0; w<size[0]; w++) {
            for(int slice=0; slice<size[2];slice++){
                pixelIndex[0] = w;   // x position
                pixelIndex[1] = h;   // y position
                pixelIndex[2] = slice;   // z position
                if (fabs(img->GetPixel(pixelIndex))>0) {
                    NSRange width = NSMakeRange(w, 1);
                    OSIROIMaskRun run;
                    run.widthRange = width;
                    run.heightIndex = h;
                    run.depthIndex = slice;
                    run.intensity = 255;
                    NSValue *miValue = [NSValue value: &run withObjCType:@encode(OSIROIMaskRun)];
                    [Array addObject:miValue];
                }
            }
        }
    }
    OSIROIMask *Mask = [[[OSIROIMask alloc] initWithMaskRuns:Array] autorelease];
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    OSIMaskROI *Roi =  [[[OSIMaskROI alloc] initWithROIMask:Mask homeFloatVolumeData:floatVolumeData name:name] autorelease];
    [[self.volumeWindow ROIManager]addROI:Roi];
}
- (void)Mask:(int)slice :(ImageTypeFloat3D::Pointer)img :(NSString*)name
{
    ImageTypeFloat3D::SizeType size = _labelCart->GetLargestPossibleRegion().GetSize();
    NSMutableArray *infarctArray  = [[[NSMutableArray alloc] init] autorelease];
    
    for (int h = 0; h<size[1]; h++) {
        for (int w=0; w<size[0]; w++) {
            ImageTypeFloat3D::IndexType pixelIndex;
            pixelIndex[0] = w;   // x position
            pixelIndex[1] = h;   // y position
            pixelIndex[2] = slice;   // z position
            
            if (fabs(img->GetPixel(pixelIndex))>0) {
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

// polar coordinates to cartesian coordinates
- (void)polar2cartesian
{
    // new image in cartesian coordinates
    ImageTypeFloat3D::Pointer image3D = ImageTypeFloat3D::New();
    DCMPix *firstPix = [[_viewControl pixList] objectAtIndex:0];
    NSUInteger slices = [[_viewControl pixList] count];
    ImageTypeFloat3D::SizeType size;
    ImageTypeFloat3D::IndexType start;
    ImageTypeFloat3D::RegionType region;
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    size[2] = slices;
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    image3D->SetRegions(region);
    image3D->Allocate();
    image3D->FillBuffer(0);
    
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> CastImageFilterType;
    CastImageFilterType::Pointer castImageFilter = CastImageFilterType::New();
    castImageFilter->SetInput(_label);
    castImageFilter->Update();
    
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
    labelGeometryImageFilter->SetInput( castImageFilter->GetOutput() );
    labelGeometryImageFilter->CalculatePixelIndicesOn();
    labelGeometryImageFilter->Update();
    LabelGeometryImageFilterType::LabelsType allLabels = labelGeometryImageFilter->GetLabels();
    LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt;
    
    LabelGeometryImageFilterType::LabelPixelType labelValue = *(allLabels.begin()+1);
    std::vector<LabelGeometryImageFilterType::LabelIndexType> vect = labelGeometryImageFilter->GetPixelIndices(labelValue);
    
    // for all pixels which are infarcted
    for (int i=0; i<vect.size(); i++) {
        ImageTypeFloat3D::IndexType index = vect.at(i);
        // transform its coordinates
        double thetaRad = M_PI*index[0]/180;
        double x = index[1]*cos(thetaRad) + _center.x;
        double y = -index[1]*sin(thetaRad) + _center.y;
        double z = index[2];
        
        ImageTypeFloat3D::IndexType indexCart;
        indexCart[0] = floor(x);
        indexCart[1] = floor(y);
        indexCart[2] = z;
        image3D->SetPixel(indexCart, _label->GetPixel(index));
    }
    _labelCart = image3D;
}

// fill the hole to find no reflow
- (void)Close
{
    // binary image
    typedef itk::BinaryThresholdImageFilter <ImageTypeFloat3D, ImageTypeFloat3D> BinaryThresholdImageFilterType;
    BinaryThresholdImageFilterType::Pointer thresholdFilter = BinaryThresholdImageFilterType::New();
    thresholdFilter->SetInput(_labelCart);
//    ImageTypeFloat3D::SizeType size=labelCart->GetLargestPossibleRegion().GetSize();
    thresholdFilter->SetLowerThreshold(0);
    thresholdFilter->SetUpperThreshold(0.1);
    thresholdFilter->SetInsideValue(0);
    thresholdFilter->SetOutsideValue(100);
    thresholdFilter->Update();
    typedef itk::VotingBinaryIterativeHoleFillingImageFilter<ImageTypeFloat3D > FilterType;
    FilterType::Pointer filter = FilterType::New();
    ImageTypeFloat3D::SizeType indexRadius;
    indexRadius[0] = 3; // radius along x
    indexRadius[1] = 3; // radius along y
    indexRadius[2] = 0; // radius along y
    filter->SetRadius( indexRadius );
    filter->SetBackgroundValue( 0 );
    filter->SetForegroundValue( 100 );
    filter->SetMajorityThreshold( 3 );
    filter->SetMaximumNumberOfIterations( 100 );
    filter->SetInput( thresholdFilter->GetOutput() );
    filter->Update();
    typedef itk::SubtractImageFilter <ImageTypeFloat3D, ImageTypeFloat3D > SubtractImageFilterType;
    SubtractImageFilterType::Pointer subtractFilter = SubtractImageFilterType::New ();
    subtractFilter->SetInput1(filter->GetOutput());
    subtractFilter->SetInput2(thresholdFilter->GetOutput());
    subtractFilter->Update();
    _noReflowCart = subtractFilter->GetOutput();
}

// compute the mask of the endocardium contour for the feature analysis
- (ImageTypeInt3D::Pointer)ComputeEndoContour
{
    ImageTypeInt3D::Pointer endoContour = ImageTypeInt3D::New();
    ImageTypeInt3D::SizeType size;
    ImageTypeInt3D::IndexType start;
    ImageTypeInt3D::RegionType region;
    
    DCMPix *firstPix = [[_viewControl pixList] objectAtIndex:0];
    NSUInteger slices = [[_viewControl pixList] count];
    
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
    pixelValue =  (float)1;
    
    NSMutableArray  *roiSeriesList = [_viewControl roiList];
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

// distance analysis
- (void)DistanceFeature:(ImageTypeInt3D::Pointer)imageLabel endoMask:(ImageTypeInt3D::Pointer)endoMask
{
    typedef itk::LabelGeometryImageFilter< ImageTypeInt3D > LabelGeometryImageFilterType;
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
    labelGeometryImageFilter->SetInput( imageLabel );
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
    
    DCMPix *firstPix = [[_viewControl pixList] objectAtIndex:0];
    std::vector<float> distance;
    int indexVector = 0;
    
    for( allLabelsIt = allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
    {
        distance.push_back(1.5);
        LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
        std::vector<LabelGeometryImageFilterType::LabelIndexType> vect = labelGeometryImageFilter->GetPixelIndices(labelValue);
        for( allLabelsItEndo = allLabelsEndo.begin()+1; allLabelsItEndo != allLabelsEndo.end(); allLabelsItEndo++ )
        {
            LabelGeometryImageFilterType::LabelPixelType labelValueEndo = *allLabelsItEndo;
            std::vector<LabelGeometryImageFilterType::LabelIndexType> indicesEndo = labelGeometryImageFilterEndo->GetPixelIndices(labelValueEndo);
            for (int i=0; i<vect.size(); i++) {
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
        indexVector +=1;
    }
    // remove all labels which have a distance to endocardium > 1.5mm
    indexVector = 0;
    for( allLabelsIt = allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
    {
        LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
        std::vector<LabelGeometryImageFilterType::LabelIndexType> vect = labelGeometryImageFilter->GetPixelIndices(labelValue);
        if ( distance.at(indexVector)>=1.5) {
            for (int i=0; i<vect.size(); i++) {
                ImageTypeFloat3D::IndexType pixelIndex;
                pixelIndex[0] = vect.at(i)[0];   // x position
                pixelIndex[1] = vect.at(i)[1];   // y position
                pixelIndex[2] = vect.at(i)[2];   // z position
                imageLabel->SetPixel(pixelIndex, 0);
            }
        }
        indexVector+=1;
    }
    
    typedef itk::CastImageFilter<ImageTypeInt3D, ImageTypeFloat3D> castTypeIF;
    castTypeIF::Pointer castIF = castTypeIF::New();
    castIF->SetInput(imageLabel);
    castIF->Update();
    _labelCart = castIF->GetOutput();
}

// volume analysis
- (ImageTypeInt3D::Pointer)volumeFeature
{
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> castTypeFI;
    castTypeFI::Pointer castFI = castTypeFI::New();
    castFI->SetInput(_labelCart);
    castFI->Update();
    
    typedef itk::MultiplyImageFilter<ImageTypeInt3D> multiplyType;
    multiplyType::Pointer multiply = multiplyType::New();
    multiply->SetInput1(castFI->GetOutput());
    multiply->SetInput2(_myocardium);
    multiply->Update();
    
    
    typedef itk::ConnectedComponentImageFilter <ImageTypeInt3D, ImageTypeInt3D> ConnectedComponentImageFilterType;
    ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
    labelFilter->SetInput(multiply->GetOutput());
    labelFilter->Update();
    
    // myocardium density = 1.055 g/cm3
    // remove all labels which have a mass < 0.1g
    typedef itk::RelabelComponentImageFilter<ImageTypeInt3D, ImageTypeInt3D> FilterType;
    FilterType::Pointer relabelFilter = FilterType::New();
    relabelFilter->SetInput( labelFilter->GetOutput() );
    float minVolumeInMm3 = 0.1/(1.05*0.001);
    
    DCMPix *firstPix = [[_viewControl pixList] objectAtIndex:0];
    float volumeOfPixelMm3 = [firstPix pixelSpacingX]*[firstPix pixelSpacingY]*[firstPix sliceInterval];
    int minsize = round( minVolumeInMm3/volumeOfPixelMm3 );
    relabelFilter->SetMinimumObjectSize( minsize );
    relabelFilter->Update();
    
    return relabelFilter->GetOutput();
}

// test if the image is defined anterior to posterior or right->left
- (BOOL)slice
{
    //ViewerController *viewerController = viewControl;
    int curIndex = [[_viewControl imageView]curImage];
    NSString        *dicomTag = @"0020,0013";
    NSArray         *pixList = [_viewControl  pixList: 0];
    DCMPix          *curPix = [pixList objectAtIndex: curIndex];
    NSString        *file_path = [curPix sourceFile];
    DCMObject       *dcmObj = [DCMObject objectWithContentsOfFile:file_path decodingPixelData:NO];
    DCMAttributeTag *tag = [[[DCMAttributeTag alloc] initWithName:dicomTag] autorelease];
    if (!tag) tag = [DCMAttributeTag tagWithTagString:dicomTag];
    NSString        *val;
    DCMAttribute    *attr;
    attr = [dcmObj attributeForTag:tag];
    val = [[attr value] description];
    NSString *stringVal=[[[NSString alloc] initWithString:val]autorelease];
    int valint=[stringVal intValue];
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
    // compute each slice on the polar coordinates
    [self imagePolar];
    //    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
    // EM algorithm
    [self EM];
    //    // return in cartesian coordinates
    [self polar2cartesian];
    // volume analysis
    ImageTypeInt3D::Pointer imageAfterVolumeAnalysis = [self volumeFeature];
    // compute the mask of the endocardium (needed for the distance analysis)
    ImageTypeInt3D::Pointer endoImage = [self ComputeEndoContour];
    // distance analysis
    [self DistanceFeature:imageAfterVolumeAnalysis endoMask:endoImage];
    // fill the holes for no reflow
    [self Close];
    
    // through the images to add on each image the OSIROI of infarct and no reflow
    //ViewerController *viewerController = [self.volumeWindow viewerController];
    int curIndex = [[_viewControl imageView]curImage];
    BOOL sliceIndex = [self slice];
    NSMutableArray  *roiSeriesList  = [_viewControl roiList];
    
    for (int j=0; j<[roiSeriesList count]; j++) {
        [_viewControl setImageIndex:j];
        [self Mask:j :_labelCart :@"hmrfMask"];
        [self Mask:j :_noReflowCart :@"hmrf: No-reflow;no"];
        [_viewControl setImageIndex:j];
    }
    
    if (sliceIndex) {
        [_viewControl setImageIndex:curIndex];
    }
    else
    {
        [_viewControl setImageIndex:(int)[roiSeriesList count]-curIndex-1];
        for (int j=0; j<[roiSeriesList count]; j++) {
            [_viewControl setImageIndex:j];
        }
        [_viewControl setImageIndex:(int)[roiSeriesList count]-curIndex-1];
    }
    //    [pool drain];
}
-(void) dealloc
{
    [_viewControl release];
    _viewControl = nil;
    //    [_volumeWindow release];
    //    _volumeWindow = nil;
    [super dealloc];
}

@end
