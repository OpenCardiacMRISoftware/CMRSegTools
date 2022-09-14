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
//  hmrfEm.m
//  CMRSegTools
//
//  Created by Coralie Vandroux on 8/14/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//


#import "hmrfEm.h"
#import "OsiriX+CMRSegTools.h"
#ifdef DEBUG_HMRF
#include <stdlib.h>
#include <stdio.h>
FILE* fichier1;
char mychar[255] ;
#endif

#include <numeric>

std::vector<LabelGeometryImageFilterType::LabelIndexType> contour;

@interface hmrfEm ()
@property (nonatomic, readwrite, retain) OSIVolumeWindow *volumeWindow;
@end

@implementation hmrfEm

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
    //    NSUInteger slices = [[viewControl pixList] count];
    ImageTypeInt3D::SizeType size;
    ImageTypeInt3D::IndexType start;
    ImageTypeInt3D::RegionType region;
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    _slicesNumber=0;
    NSMutableArray  *roiSeriesList  = [_viewControl roiList];
    for (int j=0; j<[roiSeriesList count]; j++) {
        [_viewControl setImageIndex:j];
        if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
        {
            _slicesNumber=_slicesNumber+1;
        }
    }
    size[2]=_slicesNumber;
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
    _imageDepth=0;
    std::vector<double> meanVector1,meanVector2,stdVector1,stdVector2;
    // if image is defined anterior -> posterior or right -> left
    if (sliceIndex) {
        for (int j=0; j<[roiSeriesList count]; j++) {
            [_viewControl setImageIndex:j];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                ImageTypeFloat2D::Pointer imagePolar2D = [self cartesian2polar]; // image in polar coordinates
                joinSeriesImageFilter1->PushBackInput(imagePolar2D);
                ImageTypeFloat2D::Pointer myocardium2D = [self initParam];
                ImageTypeFloat2D::Pointer myocardiumPolar2D = [self cartesian2polarMyo:myocardium2D];// myocardium mask in polar coordinates
                joinSeriesImageFilter2->PushBackInput(myocardiumPolar2D);
                
                typedef itk::BinaryThresholdImageFilter<ImageTypeFloat2D,ImageTypeFloat2D> BinaryThresholdImageFilterType;
                BinaryThresholdImageFilterType::Pointer binaryThresholdImageFilter = BinaryThresholdImageFilterType::New();
                binaryThresholdImageFilter->SetInput(imagePolar2D);
                typedef itk::LabelStatisticsImageFilter <ImageTypeFloat2D,ImageTypeInt2D > LabelStatisticsImageFilter;
                typedef itk::CastImageFilter<ImageTypeFloat2D, ImageTypeInt2D> CastImageFilterType;
                LabelStatisticsImageFilter::Pointer statFilter= LabelStatisticsImageFilter::New();
                CastImageFilterType::Pointer castImageFilter = CastImageFilterType::New();
                castImageFilter->SetInput(myocardiumPolar2D);
                castImageFilter->Update();
                statFilter->SetLabelInput(castImageFilter->GetOutput());
                statFilter->SetInput(imagePolar2D);
                statFilter->Update();
                float max=statFilter->GetMaximum(1);
                binaryThresholdImageFilter->SetLowerThreshold(0);
                binaryThresholdImageFilter->SetUpperThreshold(INITIALTHRESHOLD*max);
                binaryThresholdImageFilter->SetInsideValue(0);
                binaryThresholdImageFilter->SetOutsideValue(1);
                binaryThresholdImageFilter->Update();
                joinSeriesImageFilter3->PushBackInput(binaryThresholdImageFilter->GetOutput());
                _imageDepth=_imageDepth+1;
            }
        }
        [_viewControl setImageIndex:curIndex];
    }
    else
    {
        for (int j=[roiSeriesList count]-1; j>=0; j--)
        {
            [_viewControl setImageIndex:[roiSeriesList count]-1-j];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                ImageTypeFloat2D::Pointer imagePolar2D = [self cartesian2polar]; // image in polar coordinates
                joinSeriesImageFilter1->PushBackInput(imagePolar2D);
                ImageTypeFloat2D::Pointer myocardium2D = [self initParam];
                ImageTypeFloat2D::Pointer myocardiumPolar2D = [self cartesian2polarMyo:myocardium2D];// myocardium mask in polar coordinates
                joinSeriesImageFilter2->PushBackInput(myocardiumPolar2D);
                
                typedef itk::BinaryThresholdImageFilter<ImageTypeFloat2D,ImageTypeFloat2D> BinaryThresholdImageFilterType;
                BinaryThresholdImageFilterType::Pointer binaryThresholdImageFilter = BinaryThresholdImageFilterType::New();
                binaryThresholdImageFilter->SetInput(imagePolar2D);
                typedef itk::LabelStatisticsImageFilter <ImageTypeFloat2D,ImageTypeInt2D > LabelStatisticsImageFilter;
                typedef itk::CastImageFilter<ImageTypeFloat2D, ImageTypeInt2D> CastImageFilterType;
                LabelStatisticsImageFilter::Pointer statFilter= LabelStatisticsImageFilter::New();
                CastImageFilterType::Pointer castImageFilter = CastImageFilterType::New();
                castImageFilter->SetInput(myocardiumPolar2D);
                castImageFilter->Update();
                statFilter->SetLabelInput(castImageFilter->GetOutput());
                statFilter->SetInput(imagePolar2D);
                statFilter->Update();
                float max=statFilter->GetMaximum(1);
                binaryThresholdImageFilter->SetLowerThreshold(0);
                binaryThresholdImageFilter->SetUpperThreshold(INITIALTHRESHOLD*max);
                binaryThresholdImageFilter->SetInsideValue(0);
                binaryThresholdImageFilter->SetOutsideValue(1);
                binaryThresholdImageFilter->Update();
                joinSeriesImageFilter3->PushBackInput(binaryThresholdImageFilter->GetOutput());
                _imageDepth=_imageDepth+1;
            }
        }
        [_viewControl setImageIndex:(int)[roiSeriesList count]-curIndex-1];
    }
    joinSeriesImageFilter1->Update();
    joinSeriesImageFilter2->Update();
    joinSeriesImageFilter3->Update();
    _image = joinSeriesImageFilter1->GetOutput();
    _myocardiumPolar = joinSeriesImageFilter2->GetOutput();
    _label=joinSeriesImageFilter3->GetOutput();
    _numberWhitePixel.push_back(0);
    _time=0;
    itk::ImageRegionConstIterator<ImageTypeFloat3D> it1(_label,_label->GetLargestPossibleRegion());
    it1.GoToBegin();
    while (!it1.IsAtEnd()) {
        ImageTypeFloat3D::IndexType index=it1.GetIndex();
        if (_label->GetPixel(index)>0) {
            _numberWhitePixel.at(0)++;
        }
        ++it1;
    }
    typedef itk::LabelStatisticsImageFilter <ImageTypeFloat3D,ImageTypeInt3D > LabelStatisticsImageFilter;
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> CastImageFilterType;
    typedef itk::MultiplyImageFilter<ImageTypeFloat3D,ImageTypeFloat3D> multiplyType;
    multiplyType::Pointer multiplyHigh = multiplyType::New();
    multiplyHigh->SetInput1(_label);
    multiplyHigh->SetInput2(_myocardiumPolar);
    multiplyHigh->Update();
    CastImageFilterType::Pointer castImageFilterHigh = CastImageFilterType::New();
    castImageFilterHigh->SetInput(_label);
    castImageFilterHigh->Update();
    LabelStatisticsImageFilter::Pointer statFilterHigh= LabelStatisticsImageFilter::New();
    statFilterHigh->SetLabelInput(castImageFilterHigh->GetOutput());
    statFilterHigh->SetInput(_image);
    statFilterHigh->Update();
    _mean2=statFilterHigh->GetMean(1);
    _std2=statFilterHigh->GetSigma(1);
    _mean1=statFilterHigh->GetMean(0);
    _std1=statFilterHigh->GetSigma(0);
    
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
- (ImageTypeFloat2D::Pointer)initParam
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
    
    OSIROI* outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];
    OSIROI* insideROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
    
    if (outsideROI && insideROI) {
        
        OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
        OSIROIMask *outsideMask = [outsideROI ROIMaskForFloatVolumeData:floatVolumeData];
        OSIROIMask *insideMask = [insideROI ROIMaskForFloatVolumeData:floatVolumeData];
        OSIROIMask *myocardiumMask = [outsideMask ROIMaskBySubtractingMask:insideMask];
        NSArray *arrayMaskRuns = [myocardiumMask maskRuns];
        _myoSize.push_back(0);
        for (NSValue *value in arrayMaskRuns) {
            OSIROIMaskRun run;
            [value getValue:&run];
            NSRange range =  run.widthRange;
            for (int i = 0; i<range.length; i++) {
                ImageTypeFloat2D::IndexType pixelIndex;
                pixelIndex[0] = range.location+i;   // x position
                pixelIndex[1] = run.heightIndex;    // y position
                myocardium2D->SetPixel(pixelIndex, 1);
                _myoSize.at(_imageDepth)=_myoSize.at(_imageDepth)+1;
                ImageTypeFloat3D::IndexType pixelIndex3D;
                pixelIndex3D[0] = range.location+i;   // x position
                pixelIndex3D[1] = run.heightIndex;    // y position
                pixelIndex3D[2] = _imageDepth;     // z position
                _myocardium->SetPixel(pixelIndex3D, 1);
            }
            
        }
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
    for (int i=0; i<ITMAPMAX; i++) {
        ImageTypeFloat3D::Pointer copyLabel = _label;
        _time++;
        _numberWhitePixel.push_back(0);
        if (_labelChanged== true)
        {
            contour = [self regionGrowing];
        }
        else if (i>0)
        {
            break;
        }
        _labelChanged=false;
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
                _labelChanged = true;
                _numberWhitePixel.at(_time)++;
            }
            sum_U_MAP.at(i) = sum_U_MAP.at(i) + val;
            copyLabel->SetPixel(contour.at(j), x);
        }
        // if it converges, stop the loop
        _U = sum_U_MAP.at(i);
        
#ifdef DEBUG_HMRF
        fputs("   ",fichier1);
        snprintf(mychar,sizeof(mychar),"%d ",i);
        fputs(mychar, fichier1);
        fputs("-",fichier1);
        snprintf(mychar,sizeof(mychar),"%f" "-" "%d" "-" "%f\n",_U, _numberWhitePixel.at(_time),_U/_numberWhitePixel.at(_time));
        fputs(mychar, fichier1);
#endif
        
        _label = copyLabel;
        _stopEmForVolumeFeature=( (_numberWhitePixel.at(_time)/_numberWhitePixel.at(0)<MINIMALRATEOFCURRENTWHITEPIXELSADDED && _numberWhitePixel.at(_time)>RATEOFCHANGEFORVOLUMEFEATURE*_numberWhitePixel.at(_time-1) && _numberWhitePixel.at(_time)>RATEOFCHANGEFORVOLUMEFEATURE*_numberWhitePixel.at(_time-2)) );
        if(_stopEmForVolumeFeature==true)
        {
            [self polarVolumeFeature];
            _cleaned=true;
            _countCleaned++;
            break;
        }
        //        if (i>=3) {
        //            std::vector<double> tempVector;
        //            tempVector.push_back(sum_U_MAP.at(i-2));
        //            tempVector.push_back(sum_U_MAP.at(i-1));
        //            tempVector.push_back(sum_U_MAP.at(i));
        //            double mean = std::accumulate(tempVector.begin(), tempVector.end(), 0)/tempVector.size();
        //            std::vector<double> zero_mean(tempVector);
        //            std::transform(zero_mean.begin(), zero_mean.end(), zero_mean.begin(), std::bind2nd(std::minus<float>(), mean));
        //            double sq_sum = std::inner_product(zero_mean.begin(), zero_mean.end(), zero_mean.begin(), 0);
        //            double std = std::sqrt(sq_sum/(tempVector.size()-1));
        //            if (std/sum_U_MAP.at(i)<0.0001) {
        //                break;
        //            }
        //        }
        //snprintf(mychar,sizeof(mychar),"ITMAP: %d/%d\n",i, itMAP) ;
        //puts(mychar);
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
    //labelChanged=true;
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
    ////limitepour excellvaleurs
    
    //    snprintf(mychar,sizeof(mychar),"%f",mean2) ;
    //    fputs(mychar, fichier);
    //    fputs("         ", fichier);
    //    snprintf(mychar,sizeof(mychar),"%f",std1) ;
    //    fputs(mychar, fichier);
    //    fputs("         ", fichier);
    //    snprintf(mychar,sizeof(mychar),"%f",std2) ;
    //    fputs(mychar, fichier);
    //    fputs("         ", fichier);
    //    snprintf(mychar,sizeof(mychar),"%f",U) ;
    //    fputs(mychar, fichier);
    ////limitepour excellvaleurs
}

// EM algorithm
- (void)EM
{
#ifdef DEBUG_HMRF
    NSURL* dir = [[NSURL fileURLWithPath:NSHomeDirectory()] URLByAppendingPathComponent:@"Desktop/HMRF_Results"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir.path])
        [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    fichier1 = fopen([[dir URLByAppendingPathComponent:@"IntermediateResults(9,200)2.csv"] fileSystemRepresentation], "w");
    //if (!fichier)
    //    erreur
#endif
    
    std::vector<double> sum_U;
    for (int i=0; i<ITEMMAX; i++) {
        if (_cleaned==true)
        {
            _labelChanged=true;
            if (_countCleaned==1)
            {
                typedef itk::MultiplyImageFilter<ImageTypeFloat3D> multiplyType;
                multiplyType::Pointer multiply = multiplyType::New();
                multiply->SetInput1(_label);
                multiply->SetInput2(_myocardiumPolar);
                multiply->Update();
                _label = multiply->GetOutput();
                typedef itk::LabelStatisticsImageFilter <ImageTypeFloat3D,ImageTypeInt3D > LabelStatisticsImageFilter1;
                LabelStatisticsImageFilter1::Pointer statFilterHigh1= LabelStatisticsImageFilter1::New();
                typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> CastImageFilterType;
                CastImageFilterType::Pointer castImageFilterHigh = CastImageFilterType::New();
                castImageFilterHigh->SetInput(_label);
                castImageFilterHigh->Update();
                statFilterHigh1->SetLabelInput(castImageFilterHigh->GetOutput());
                statFilterHigh1->SetInput(_image);
                statFilterHigh1->Update();
                _mean2=statFilterHigh1->GetMean(1);
                _std2=statFilterHigh1->GetSigma(1);
                _mean1=statFilterHigh1->GetMean(0);
                _std1=statFilterHigh1->GetSigma(0);
                _multiplywithmyo=true;
            }
        }
        [self EStep];
        [self MStep];
        // if it converges, stop the loop
        sum_U.push_back(_U);
        if (i>=3) {
            std::vector<double> tempVector;
            tempVector.push_back(sum_U.at(i-3));
            tempVector.push_back(sum_U.at(i-2));
            tempVector.push_back(sum_U.at(i-1));
            tempVector.push_back(sum_U.at(i));
            double min = *min_element(tempVector.begin(), tempVector.end());
            double max = *max_element(tempVector.begin(), tempVector.end());
            double h=100*fabs(min/max-1);
            if (h< RATETOSTOP && _multiplywithmyo==true)// && numberWhitePixel.at(time)<0.001*numberWhitePixel.at(0))
            {
                break;
            }
        }
        //snprintf(mychar,sizeof(mychar),"ITEM: %d/%d\n",i, itEM);
        //puts(mychar);
    }
    _labelChanged=true;
#ifdef DEBUG_HMRF
    fclose(fichier1);
#endif
}

// get the OSIROIMask of the mask in ITK
- (void)MaskWithsliceOfImage:(int)sliceOfImage sliceOfRoi:(int)sliceOfRoi :(ImageTypeFloat3D::Pointer)img :(NSString*)name
{
    ImageTypeFloat3D::SizeType size = img->GetLargestPossibleRegion().GetSize();
    NSMutableArray *infarctArray  = [[[NSMutableArray alloc] init] autorelease];
    
    for (int h = 0; h<size[1]; h++) {
        for (int w=0; w<size[0]; w++) {
            ImageTypeFloat3D::IndexType pixelIndex;
            pixelIndex[0] = w;   // x position
            pixelIndex[1] = h;   // y position
            pixelIndex[2] = sliceOfImage;   // z position
            
            if (fabs(img->GetPixel(pixelIndex))>0) {
                NSRange width = NSMakeRange(w, 1);
                OSIROIMaskRun run;
                run.widthRange = width;
                run.heightIndex = h;
                run.depthIndex = sliceOfRoi;
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
    //NSUInteger slices = [[viewControl pixList] count];
    ImageTypeFloat3D::SizeType size;
    ImageTypeFloat3D::IndexType start;
    ImageTypeFloat3D::RegionType region;
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    size[2] = _slicesNumber;
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
    ImageTypeInt3D::Pointer image3D;
    { // initialize image3D...
        typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> castTypeIF;
        castTypeIF::Pointer castIF = castTypeIF::New();
        castIF->SetInput(_labelCart);
        castIF->Update();
        typedef itk::SubtractImageFilter <ImageTypeInt3D, ImageTypeInt3D >SubtractImageFilterType;
        SubtractImageFilterType::Pointer subtractFilter= SubtractImageFilterType::New ();
        subtractFilter->SetInput1(_myocardium);
        subtractFilter->SetInput2(castIF->GetOutput());
        subtractFilter->Update();
        image3D = subtractFilter->GetOutput();
    }
    //[self copyIntImage3D:[self relabelingForVisualisationInt:image3D]];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    //dispatch_apply(_slicesNumber, queue, ^(size_t sliceNumber) {
    for (size_t sliceNumber = 0; sliceNumber < _slicesNumber; ++sliceNumber) {
#if DEBUG == 1
        NSLog(@"Starting [hmrfEm Close] for slice number %lu", sliceNumber);
#endif
        
        __block ImageTypeInt2D::Pointer noReflow2D = ImageTypeInt2D::New();
        //        ImageTypeInt2D::Pointer intermediateImage = ImageTypeInt2D::New();
        DCMPix *firstPix = [[_viewControl pixList] objectAtIndex:0];
        //NSUInteger slices = [[viewControl pixList] count];
        ImageTypeInt2D::SizeType size;
        ImageTypeInt2D::IndexType start;
        ImageTypeInt2D::RegionType region;
        size[0] = [firstPix pwidth];
        size[1] = [firstPix pheight];
        start.Fill(0);
        region.SetIndex(start);
        region.SetSize(size);
        noReflow2D->SetRegions(region);
        noReflow2D->Allocate();
        noReflow2D->FillBuffer(0);
        //        intermediateImage->SetRegions(region);
        //        intermediateImage->Allocate();
        //        intermediateImage->FillBuffer(0);
        itk::ImageRegionConstIterator<ImageTypeInt2D> it(noReflow2D,noReflow2D->GetLargestPossibleRegion());//region est une région contenant le myocarde
        it.GoToBegin();//
        while (!it.IsAtEnd()) {
            ImageTypeInt3D::IndexType index;
            index[0]=it.GetIndex()[0];
            index[1]=it.GetIndex()[1];
            index[2]=sliceNumber;
            int h=image3D->GetPixel(index);
            if (h>0){
                noReflow2D->SetPixel(it.GetIndex(),1);
            }
            ++it;
        }
        typedef itk::ConnectedComponentImageFilter <ImageTypeInt2D, ImageTypeInt2D> ConnectedComponentImageFilterType;
        ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
        labelFilter->SetFullyConnected(false);
        labelFilter->SetInput(noReflow2D);
        labelFilter->Update();
        noReflow2D=labelFilter->GetOutput();
        typedef itk::LabelGeometryImageFilter< ImageTypeInt2D > LabelGeometryImageFilterType;
        LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
        labelGeometryImageFilter->SetInput(labelFilter->GetOutput());
        labelGeometryImageFilter->CalculatePixelIndicesOn();
        labelGeometryImageFilter->Update();
        
        LabelGeometryImageFilterType::LabelsType allLabels = labelGeometryImageFilter->GetLabels();
        
        NSLog(@"........ [hmrfEm Close] for slice number %lu has %lu labels...", sliceNumber, allLabels.size());
        
        __block auto allLabelsIt = allLabels.begin();   // the original loop was for( allLabelsIt = allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
        dispatch_apply(allLabels.size()-1, queue, ^(size_t someIndex)
        {
            LabelGeometryImageFilterType::LabelPixelType labelValue;
            @synchronized(self) {
                ++allLabelsIt;                  // so by incrementing here we match that begin()+1... but did it make sense?
                labelValue = *allLabelsIt;
            }
            
            std::vector<LabelGeometryImageFilterType::LabelIndexType> indices = labelGeometryImageFilter->GetPixelIndices(labelValue);
            int count;
            count=0;
            for (int i=0; i<indices.size(); i++)
            {
                ImageTypeInt2D::IndexType idx;
                idx[0] = indices.at(i)[0];
                idx[1] = indices.at(i)[1];
                //idx[2] = indices.at(i)[2];
                if (noReflow2D->GetPixel(idx)>0)
                {
                    count=count+1;
                }
            }
            if (count>_myoSize.at(sliceNumber)*RATEOSSIZE)
            {
                for (int i=0; i<indices.size(); i++) {
                    ImageTypeInt2D::IndexType idx;
                    idx[0] = indices.at(i)[0];
                    idx[1] = indices.at(i)[1];
                    noReflow2D->SetPixel(idx, 0);
                    //                    ImageTypeInt3D::IndexType idx1;
                    //                    idx1[0] = indices.at(i)[0];
                    //                    idx1[1] = indices.at(i)[1];
                    //                    idx1[2] = l;
                    //                    image3D->SetPixel(idx1,0);
                }
                return;
            }
            //        }
            //        for( allLabelsIt = allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
            //        {
            //            LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
            //            std::vector<LabelGeometryImageFilterType::LabelIndexType> indices = labelGeometryImageFilter->GetPixelIndices(labelValue);
            typedef itk::CastImageFilter<ImageTypeInt2D, ImageTypeFloat2D> castTypeIF;
            castTypeIF::Pointer castIF = castTypeIF::New();
            castIF->SetInput(noReflow2D);
            castIF->Update();
            typedef itk::ThresholdImageFilter <ImageTypeFloat2D> ThresholdImageFilterType;
            ThresholdImageFilterType::Pointer thresholdFilter = ThresholdImageFilterType::New();
            thresholdFilter->SetInput(castIF->GetOutput());
            float h1=labelValue-0.50;
            float h2=labelValue+0.50;
            //thresholdFilter->SetLower(h1);
            //thresholdFilter->SetUpper(h2);
            thresholdFilter->ThresholdOutside(h1, h2);
            thresholdFilter->SetOutsideValue(0);
            thresholdFilter->Update();
            typedef itk::BinaryContourImageFilter<ImageTypeFloat2D, ImageTypeFloat2D> BinaryContourImageFilterType;
            BinaryContourImageFilterType::Pointer binaryContourImageFilter = BinaryContourImageFilterType::New();
            binaryContourImageFilter->SetInput(thresholdFilter->GetOutput());
            binaryContourImageFilter->SetForegroundValue(0);
            binaryContourImageFilter->SetBackgroundValue(labelValue);
            binaryContourImageFilter->Update();
            //[self copyImage:binaryContourImageFilter->GetOutput()];
            //break;
            typedef itk::CastImageFilter<ImageTypeFloat2D, ImageTypeInt2D> CastImageFilterType1;
            CastImageFilterType1::Pointer castImageFilter1 = CastImageFilterType1::New();
            castImageFilter1->SetInput(binaryContourImageFilter->GetOutput());
            castImageFilter1->Update();
            
            LabelGeometryImageFilterType::Pointer labelGeometryImageFilter1 = LabelGeometryImageFilterType::New();
            labelGeometryImageFilter1->SetInput( castImageFilter1->GetOutput() );
            labelGeometryImageFilter1->CalculatePixelIndicesOn();
            labelGeometryImageFilter1->Update();
            LabelGeometryImageFilterType::LabelsType allLabels1 = labelGeometryImageFilter1->GetLabels();
            LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt1;
            //intermediateImage=castImageFilter1->GetOutput();
            
            std::vector<LabelGeometryImageFilterType::LabelIndexType> vect;
            for( allLabelsIt1 = allLabels1.begin(); allLabelsIt1 != allLabels1.end(); allLabelsIt1++ )
            {
                LabelGeometryImageFilterType::LabelPixelType labelValue1 = *allLabelsIt1;
                if (labelValue1==0) {
                    vect = labelGeometryImageFilter1->GetPixelIndices(labelValue1);
                    break;
                }
            }
            
            float nonInfarctNeighboor=0; // TODO: make this a local if poss
            for (int j=0; j<vect.size(); j++) {
                ImageTypeFloat3D::IndexType index;
                index[0]=vect.at(j)[0];
                index[1]=vect.at(j)[1];
                index[2]=sliceNumber;
                if (_labelCart->GetPixel(index)==0)
                {
                    nonInfarctNeighboor++;
                }
            }
            if(nonInfarctNeighboor > RATEOFNONINFARTEDNEIGHBOR*vect.size()) @synchronized(self) { // affects noReflow2D, only one thread at a time
                typedef itk::SubtractImageFilter <ImageTypeInt2D, ImageTypeInt2D >SubtractImageFilterType;
                SubtractImageFilterType::Pointer subtractFilter= SubtractImageFilterType::New ();
                subtractFilter->SetInput1(noReflow2D);
                CastImageFilterType1::Pointer castImageFilter2 = CastImageFilterType1::New();
                castImageFilter2->SetInput(thresholdFilter->GetOutput());
                castImageFilter2->Update();
                subtractFilter->SetInput2(castImageFilter2->GetOutput());
                subtractFilter->Update();
                noReflow2D=subtractFilter->GetOutput();
                for (int i=0; i<indices.size(); i++) {
                    ImageTypeInt3D::IndexType idx;
                    idx[0] = indices.at(i)[0];
                    idx[1] = indices.at(i)[1];
                    idx[2] = sliceNumber;
                    image3D->SetPixel(idx, 0);
                }
            }
        });
        
        itk::ImageRegionConstIterator<ImageTypeInt2D> it1(noReflow2D,noReflow2D->GetLargestPossibleRegion());//region est une région contenant le myocarde
        it1.GoToBegin();//
        while (!it1.IsAtEnd()) {
            //ImageTypeFloat3D=
            ImageTypeInt3D::IndexType idx;
            idx[0] = it1.GetIndex()[0];
            idx[1] = it1.GetIndex()[1];
            idx[2] = sliceNumber;
            image3D->SetPixel(idx, noReflow2D->GetPixel(it1.GetIndex()));
            ++it1;
        }
        
#if DEBUG == 1
        NSLog(@"........ [hmrfEm Close] for slice number %lu done", sliceNumber);
#endif
    }
    
    //    [self copyIntImage3D:[self relabelingForVisualisationInt:image3D]];
    typedef itk::CastImageFilter<ImageTypeInt3D , ImageTypeFloat3D> castTypeIF1;
    castTypeIF1::Pointer castIF1 = castTypeIF1::New();
    castIF1->SetInput(image3D);
    castIF1->Update();
    _noReflowCart=castIF1->GetOutput();
    //   [self copyFloatImage3D:[self relabelingForVisualisationFloat:binaryContourImageFilter->GetOutput()]];
    
    
    
    
    //    typedef itk::RelabelComponentImageFilter<ImageTypeFloat3D, ImageTypeInt3D> FilterType;
    //    FilterType::Pointer relabelFilter = FilterType::New();
    //    relabelFilter->SetInput( castIF1->GetOutput() );
    //
    //    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    //    float volumeOfPixelMm3 = [firstPix pixelSpacingX]*[firstPix pixelSpacingY]*[firstPix sliceInterval];
    //    int minsize = round( minVolumeInMm3/volumeOfPixelMm3 );
    //    relabelFilter->SetMinimumObjectSize( minsize );
    //    relabelFilter->Update();
    //
    //    noReflowCart = castIF->GetOutput();
    //    [self copyFloatImage3D:[self relabelingForVisualisationFloat:noReflowCart]];
    //    // binary image
    //    typedef itk::BinaryThresholdImageFilter <ImageTypeFloat3D, ImageTypeFloat3D> BinaryThresholdImageFilterType;
    //    BinaryThresholdImageFilterType::Pointer thresholdFilter = BinaryThresholdImageFilterType::New();
    //    thresholdFilter->SetInput(labelCart);
    //    ImageTypeFloat3D::SizeType size=labelCart->GetLargestPossibleRegion().GetSize();
    //    thresholdFilter->SetLowerThreshold(0);
    //    thresholdFilter->SetUpperThreshold(0.1);
    //    thresholdFilter->SetInsideValue(0);
    //    thresholdFilter->SetOutsideValue(100);
    //    thresholdFilter->Update();
    //    typedef itk::VotingBinaryIterativeHoleFillingImageFilter<ImageTypeFloat3D > FilterType;
    //    FilterType::Pointer filter = FilterType::New();
    //    ImageTypeFloat3D::SizeType indexRadius;
    //    indexRadius[0] = 3; // radius along x
    //    indexRadius[1] = 3; // radius along y
    //    indexRadius[2] = 0; // radius along y
    //    filter->SetRadius( indexRadius );
    //    filter->SetBackgroundValue( 0 );
    //    filter->SetForegroundValue( 100 );
    //    filter->SetMajorityThreshold( 3 );
    //    filter->SetMaximumNumberOfIterations( 100 );
    //    filter->SetInput( thresholdFilter->GetOutput() );
    //    filter->Update();
    //    typedef itk::SubtractImageFilter <ImageTypeFloat3D, ImageTypeFloat3D > SubtractImageFilterType;
    //    SubtractImageFilterType::Pointer subtractFilter = SubtractImageFilterType::New ();
    //    subtractFilter->SetInput1(filter->GetOutput());
    //    subtractFilter->SetInput2(thresholdFilter->GetOutput());
    //    subtractFilter->Update();
}

// compute the mask of the endocardium contour for the feature analysis
- (ImageTypeInt3D::Pointer)ComputeEndoContour
{
    ImageTypeInt3D::Pointer endoContour = ImageTypeInt3D::New();
    ImageTypeInt3D::SizeType size;
    ImageTypeInt3D::IndexType start;
    ImageTypeInt3D::RegionType region;
    
    DCMPix *firstPix = [[_viewControl pixList] objectAtIndex:0];
    //NSUInteger slices = [[viewControl pixList] count];
    
    //Size Width * Height * NoOfSlices
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    size[2] = _slicesNumber;
    
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    endoContour->SetRegions(region);
    endoContour->Allocate();
    endoContour->FillBuffer(0);
    ImageTypeFloat3D::PixelType   pixelValue;
    pixelValue =  (float)1;
    _imageDepth=0;
    NSMutableArray  *roiSeriesList = [_viewControl roiList];
    if ([self slice])
    {
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
                        pixelIndex[2] = _imageDepth;   // z position
                        endoContour->SetPixel(   pixelIndex,   pixelValue  );
                    }
                }
            }
            [_viewControl setImageIndex:numSeries];
            OSIROI* outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];
            OSIROI* insideROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
            
            if (outsideROI && insideROI) {
                _imageDepth=_imageDepth+1;
            }
        }
    }
    else
    {
        for (int numSeries=[roiSeriesList count]-1;numSeries>=0; numSeries--) {
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
                        pixelIndex[2] = _imageDepth;   // z position
                        endoContour->SetPixel(   pixelIndex,   pixelValue  );
                    }
                }
            }
            [_viewControl needsDisplayUpdate];
            [_viewControl setImageIndex:[roiSeriesList count]-1-numSeries];
            OSIROI* outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];
            OSIROI* insideROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
            
            if (outsideROI && insideROI) {
                _imageDepth=_imageDepth+1;
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
    relabelFilter->SetMinimumObjectSize(MULTIPLYINGFACTOROFVOLUMEFEATURE*minsize);
    relabelFilter->Update();
    
    return relabelFilter->GetOutput();
}
-(void)polarVolumeFeature
{
    typedef itk::MultiplyImageFilter<ImageTypeFloat3D> multiplyType;
    multiplyType::Pointer multiply = multiplyType::New();
    multiply->SetInput1(_label);
    multiply->SetInput2(_myocardiumPolar);
    multiply->Update();
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> castTypeFI;
    castTypeFI::Pointer castFI = castTypeFI::New();
    castFI->SetInput(multiply->GetOutput());
    castFI->Update();
    
    typedef itk::ConnectedComponentImageFilter <ImageTypeInt3D, ImageTypeInt3D> ConnectedComponentImageFilterType;
    ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
    labelFilter->SetInput(castFI->GetOutput());
    labelFilter->Update();
    typedef itk::LabelGeometryImageFilter< ImageTypeInt3D > LabelGeometryImageFilterType;
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
    labelGeometryImageFilter->SetInput( labelFilter->GetOutput() );
    labelGeometryImageFilter->CalculatePixelIndicesOn();
    labelGeometryImageFilter->Update();
    LabelGeometryImageFilterType::LabelsType allLabels = labelGeometryImageFilter->GetLabels();
    LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt;
    float minVolumeInMm3 = 0.1/(1.05*0.001);
    DCMPix *firstPix = [[_viewControl pixList] objectAtIndex:0];
    float volumeOfPixelMm3 = [firstPix pixelSpacingX]*[firstPix pixelSpacingY]*[firstPix spacingBetweenSlices];
    volumeOfPixelMm3 = [firstPix pixelSpacingX]*[firstPix pixelSpacingY]*[firstPix sliceInterval];
    //    float minsize = round( minVolumeInMm3/volumeOfPixelMm3 ); // commented unused variable -spalte
    
    for( allLabelsIt= allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
    {
        int volumeSize=0;
        LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
        std::vector<LabelGeometryImageFilterType::LabelIndexType> indices = labelGeometryImageFilter->GetPixelIndices(labelValue);
        ImageTypeFloat3D::IndexType p1;
        for (int j=0; j<indices.size(); j++) {
            p1[0] = indices.at(j)[0];
            p1[1] = indices.at(j)[1];
            p1[2] = indices.at(j)[2];
            volumeSize=volumeSize+[firstPix sliceInterval]*M_PI*(2*p1[1]-1)/360;
        }
        if ( volumeSize < minVolumeInMm3)
        {
            for (int j=0; j<indices.size(); j++) {
                p1[0] = indices.at(j)[0];
                p1[1] = indices.at(j)[1];
                p1[2] = indices.at(j)[2];
                _label->SetPixel(p1, 0);
                _image->SetPixel(p1, 0);
            }
        }
    }
    
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
    _multiplywithmyo=false;
    _labelChanged=true;
    _cleaned=false;
    _countCleaned=0;
    _stopEmForVolumeFeature=false;
    // set maximum of iteration :
    // compute each slice on the polar coordinates
    [self imagePolar];
    // EM algorithm
    [self EM];
    // return in cartesian coordinates
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
    _imageDepth=0;
    if (sliceIndex)
    {
        for (int j=0; j<[roiSeriesList count]; j++) {
            [_viewControl setImageIndex:j];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                [self MaskWithsliceOfImage:_imageDepth sliceOfRoi:j :_labelCart :@"hmrfMask"];
                [self MaskWithsliceOfImage:_imageDepth sliceOfRoi:j :_noReflowCart :@"hmrf: No-reflow;no"];
                _imageDepth=_imageDepth+1;
            }
        }
    }
    else
    {
        for (int j=[roiSeriesList count]-1;j>=0; j--) {
            [_viewControl setImageIndex:[roiSeriesList count]-j-1];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                [self MaskWithsliceOfImage:_imageDepth sliceOfRoi:j :_labelCart :@"hmrfMask"];
                [self MaskWithsliceOfImage:_imageDepth sliceOfRoi:j :_noReflowCart :@"hmrf: No-reflow;no"];
                _imageDepth=_imageDepth+1;
            }
        }
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
}
-(void) dealloc
{
    //    [viewControl release];
    //    viewControl = nil;
    //    [_volumeWindow release];
    //    _volumeWindow = nil;
    [super dealloc];
}

@end
