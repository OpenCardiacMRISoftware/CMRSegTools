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
//  gaussianMixtureModel.m
//  CMRSegTools
//
//  Created by Coralie Vandroux on 8/13/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "gaussianMixtureModel.h"
#define PI 3.14159265358979323846
#define epsilon 0.01
#define maxIter 200

@interface gaussianMixtureModel ()
@property (nonatomic, readwrite, retain) OSIVolumeWindow *volumeWindow;
@end

@implementation gaussianMixtureModel

@synthesize volumeWindow = _volumeWindow;

// initialization
- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow
{
    self.volumeWindow = volumeWindow;
    return self;
}

// pixels contained in the myocardium and initial parameters
- (void)myocardiumPixel
{
    std::vector<int> myocardiumPix;
    OSIROI* outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];
    OSIROI* insideROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
    if (outsideROI && insideROI) {
        ViewerController *viewerController = [self.volumeWindow viewerController];
        int curIndex = [[viewerController imageView]curImage];
        DCMPix  *curPix = [[viewerController pixList] objectAtIndex: curIndex];
        float   *fImageA = [curPix fImage];
        long pwidth = [curPix pwidth];
        long pheight = [curPix pheight];
        
        // we transform the current image into vtkImageImport
        vtkImageImport *image = vtkImageImport::New();
        image->SetDataScalarTypeToFloat();
        image->SetImportVoidPointer(fImageA);
        image->SetWholeExtent(0,(int)pwidth-1, 0,(int)pheight-1, 0,0);
        image->SetDataExtentToWholeExtent();
        image->Update();
        vtkUCharImageData *img     = vtkUCharImageData::New();
        
        if ( image->GetOutput()->GetScalarType() != VTK_UNSIGNED_CHAR )
        {
            double min = image->GetOutput()->GetScalarRange()[0];
            double max = image->GetOutput()->GetScalarRange()[1];
            double diff = max-min;
            double slope = max/diff;
            double inter = -slope*min;
            double shift = inter/slope;
            vtkImageShiftScale *shifter = vtkImageShiftScale::New();
            shifter->SetShift(shift);
            shifter->SetScale(slope);
            shifter->SetInputConnection(image->GetOutputPort());
            shifter->ReleaseDataFlagOff();
            shifter->SetOutputScalarTypeToUnsignedChar();
            shifter->Update();
            img->CopyImage(shifter->GetOutput());
        }
        else
            img->CopyImage(image->GetOutput());
        
        OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
        OSIROIMask* outsideMask = [outsideROI ROIMaskForFloatVolumeData:floatVolumeData];
        OSIROIMask* insideMask = [insideROI ROIMaskForFloatVolumeData:floatVolumeData];
        OSIROIMask *myocardiumMask = [outsideMask ROIMaskBySubtractingMask:insideMask];
        
        NSArray *indexes = [myocardiumMask maskIndexes];
        for (int num=0; num<[indexes count]; num++) {
            NSValue *value = [indexes objectAtIndex:num];
            OSIROIMaskIndex index;
            [value getValue:&index];
            myocardiumPix.push_back((*img)(index.x,index.y));
        }
        
        pixel = myocardiumPix;
        
        // set initial parameters : mean, variance, and w.
        OSIMaskROI *myocardiumROI = [[[OSIMaskROI alloc] initWithROIMask:myocardiumMask homeFloatVolumeData:floatVolumeData name:@"myocardium"] autorelease];
        OSIROIFloatPixelData *floatPixelData = [myocardiumROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData];
        float regionMax = [floatPixelData intensityMax];
        
        NSPredicate *thresholdPredicate = [NSPredicate predicateWithFormat:@"self.intensity >= %f", regionMax/2];
        OSIROIMask *thresholdMask = [myocardiumMask filteredROIMaskUsingPredicate:thresholdPredicate floatVolumeData:floatVolumeData];
        OSIROIMask *normalMask = [myocardiumMask ROIMaskBySubtractingMask:thresholdMask];
        OSIMaskROI *thresholdROI = [[[OSIMaskROI alloc] initWithROIMask:thresholdMask homeFloatVolumeData:floatVolumeData name:@"threshold"] autorelease];
        OSIMaskROI *normalROI = [[[OSIMaskROI alloc] initWithROIMask:normalMask homeFloatVolumeData:floatVolumeData name:@"normal"] autorelease];
        OSIROIFloatPixelData *floatPixelDataThreshold = [thresholdROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData];
        mean2 = [floatPixelDataThreshold intensityMean];
        var2 = [floatPixelDataThreshold intensityStandardDeviation]*[floatPixelDataThreshold intensityStandardDeviation];
        OSIROIFloatPixelData *floatPixelDataNormal = [normalROI ROIFloatPixelDataForFloatVolumeData:floatVolumeData];
        mean1 = [floatPixelDataNormal intensityMean];
        var1 = [floatPixelDataNormal intensityStandardDeviation]*[floatPixelDataNormal intensityStandardDeviation];
        w1 = 0.8;
        w2 = 0.2;
    }
}

// compute y = Bessel0(x)
- (double)Bessel0:(double)x
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

// compute y = Bessel1(x)
- (double)Bessel1:(double)x
{
    double ax,ans;
    double y;
    //Accumulate polynomials in double precision.
    if ((ax=fabs(x)) < 3.75) {//Polynomial fit.
        y=x/3.75;
        y*=y;
        ans=ax*(0.5+y*(0.87890594+y*(0.51498869+y*(0.15084934
                                                   +y*(0.2658733e-1+y*(0.301532e-2+y*0.32411e-3))))));
    } else {
        y=3.75/ax;
        ans=0.2282967e-1+y*(-0.2895312e-1+y*(0.1787654e-1
                                             -y*0.420059e-2));
        ans=0.39894228+y*(-0.3988024e-1+y*(-0.362018e-2
                                           +y*(0.163801e-2+y*(-0.1031555e-1+y*ans))));
        ans *= (exp(ax)/sqrt(ax));
    }
    return x < 0.0 ? -ans : ans;
}

// compute y = Rice(x)
- (double)RicePdf:(double)_x :(double)_mean :(double)_variance
{
    double y;
    y = (_x/_variance) * exp(-(_x*_x+_mean*_mean)/(2*_variance)) * [self Bessel0:(_x*_mean)/_variance];
    return y;
}

// compute y = Gaussian(x)
- (double)GaussianPdf:(double)_x :(double)_mean :(double)_variance
{
    double y;
    y = (1/sqrt(2*PI*_variance)) * exp(-(_x-_mean)*(_x-_mean)/(2*_variance));
    return y;
}

// E Step : evaluate expectation
- (void)EStep
{
    int size = pixel.size();
    sumPDF1 = 0;
    sumPDF2 = 0;
    sumPDF1x = 0;
    sumPDF2x = 0;
    sumPDF1x2 = 0;
    sumPDF2x2 = 0;

    PDF1.erase(PDF1.begin(), PDF1.end());
    PDF2.erase(PDF2.begin(), PDF2.end());
    
    for (int i=0; i<size; i++) {
        if ([type isEqualToString:@"rice"]) { // Rice Model
            double pdf1 = w1 * [self RicePdf:pixel.at(i) :mean1 :var1];
            double pdf2 = w2 * [self GaussianPdf:pixel.at(i) :mean2 :var2];
            PDF1.push_back(pdf1/(pdf1+pdf2));
            PDF2.push_back(pdf2/(pdf1+pdf2));
            
            sumPDF1    =  sumPDF1 + PDF1.back();
            sumPDF2    =  sumPDF2 + PDF2.back();
            double var = (pixel.at(i)*mean1)/var1;
            sumPDF1x   =  sumPDF1x + PDF1.back() * pixel.at(i) * ([self Bessel1:var]/[self Bessel0:var]);
            sumPDF2x   =  sumPDF2x + PDF2.back() * pixel.at(i);
            sumPDF1x2  =  sumPDF1x2 + PDF1.back()* pixel.at(i)*pixel.at(i);
        }
        else if ([type isEqualToString:@"gaussian"]) { // Gaussian Model
            double pdf1 = w1 * [self GaussianPdf:pixel.at(i) :mean1 :var1];
            double pdf2 = w2 * [self GaussianPdf:pixel.at(i) :mean2 :var2];
            PDF1.push_back(pdf1/(pdf1+pdf2));
            PDF2.push_back(pdf2/(pdf1+pdf2));
            
            sumPDF1    =  sumPDF1 + PDF1.back();
            sumPDF2    =  sumPDF2 + PDF2.back();
            sumPDF1x   =  sumPDF1x + PDF1.back() * pixel.at(i);
            sumPDF2x   =  sumPDF2x + PDF2.back() * pixel.at(i);
        }
    }
}

// M Step : update parameters
- (void)MStep
{
    int size = pixel.size();
    if ([type isEqualToString:@"rice"]) { // Rice Model
        nw1         = (1/(double)size) * sumPDF1;
        nw2         = (1/(double)size) * sumPDF2;
        nmean1      = (1/ (size*nw1) ) * sumPDF1x;
        nmean2      = (1/ (size*nw2) ) * sumPDF2x;
        for (int i=0; i<pixel.size(); i++) {
            sumPDF2x2  =  sumPDF2x2 + PDF2.at(i) * (pixel.at(i)-nmean2)*(pixel.at(i)-nmean2);
        }
        nvar1  = ((1/ (size*nw1) ) * sumPDF1x2 - nmean1)/2;
        nvar2  = (1/ (size*nw2) ) * sumPDF2x2;
    }
    else if ([type isEqualToString:@"gaussian"]) { // Gaussian Model
        nw1         = (1/(double)size) * sumPDF1;
        nw2         = (1/(double)size) * sumPDF2;
        nmean1      = (1/ (size*nw1) ) * sumPDF1x;
        nmean2      = (1/ (size*nw2) ) * sumPDF2x;
        for (int i=0; i<pixel.size(); i++) {
            sumPDF1x2  =  sumPDF1x2 + PDF1.at(i) * (pixel.at(i)-nmean1)*(pixel.at(i)-nmean1);
            sumPDF2x2  =  sumPDF2x2 + PDF2.at(i) * (pixel.at(i)-nmean2)*(pixel.at(i)-nmean2);
        }
        nvar1  = (1/ (size*nw1) ) * sumPDF1x2;
        nvar2  = (1/ (size*nw2) ) * sumPDF2x2;
    }
}

// EM algorithm
- (void)EM
{
    int nb = 0;
    double difMean1 = 10;
    double difVar1 = 10;
    do {
        [self EStep];
        [self MStep];
        difMean1 = fabs(mean1-nmean1);
        difVar1 = fabs(var1-nvar1);
        nb ++;
        mean1 = nmean1;
        mean2 = nmean2;
        var1 = nvar1;
        var2 = nvar2;
        w1 = nw1;
        w2 = nw2;
    } while ((difMean1>epsilon || difVar1>epsilon) && nb<maxIter);
}

// get the intersection of the rice model and gaussian model
- (double)getIntersection
{
    double x;
    int max= *std::max_element(pixel.begin(),pixel.end());
    std::vector<double> dif;
    for (float i=nmean1; i<(nmean2+max)/2; i+=0.01) {
        dif.push_back(abs(nw1*[self RicePdf:i :nmean1 :nvar1]-nw2*[self GaussianPdf:i :nmean2 :nvar2]));
    }
    x = round((std::min_element(dif.begin(), dif.end())-dif.begin())/100 + nmean1);
    return x;
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

- (void)compute:(NSString*)TypeOfDistribution
{
    // 2 gaussian or a Rice moedel and a gaussian :
    type = TypeOfDistribution;
    std::vector<double> meanM1;
    std::vector<double> meanS1;
    
    // browse all the slices , apply GMM on each one
    ViewerController *viewerController = [self.volumeWindow viewerController];
    int curIndex = [[viewerController imageView]curImage];
    BOOL sliceIndex = [self slice];
    NSMutableArray  *roiSeriesList  = [viewerController roiList];
    
    for (int j=0; j<[roiSeriesList count]; j++) {
        [viewerController setImageIndex:j];
        
        OSIROI *outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];
        OSIROI *insideROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
        if (outsideROI && insideROI) {
            // pixel contained in the myocardium
            [self myocardiumPixel];
            // EM algorithm
            [self EM];
            ROI *outsideBaseROI = [[outsideROI osiriXROIs]anyObject];
            // set magic name 
            if (nmean1>0) {
                // we change it's name
                NSMutableString *newName = [NSMutableString stringWithString:@"CMRSegTools: Epicardium"];
                if ([type isEqualToString:@"rice"]) {
                    double intersect = [self getIntersection];
                    [newName appendFormat:@";GMM_%f",intersect];
                    [outsideBaseROI setName:newName];
                }
                else if ([type isEqualToString:@"gaussian"]){
                    [newName appendFormat:@";HsuMean_%f;HsuStd_%f", nmean1,sqrt(nvar1)];
                    [outsideBaseROI setName:newName];
                    
                }
                [outsideBaseROI setComments:[NSString stringWithFormat:@"Mean1_%f;Mean2_%f;Std1_%f;Std2_%f;w1_%f;w2_%f;Num_%f", nmean1,nmean2,sqrt(nvar1),sqrt(nvar2),nw1,nw2,(double)pixel.size()]];
            }
        }
    }
    if (sliceIndex)
        [viewerController setImageIndex:curIndex];
    else
        [viewerController setImageIndex:(int)[roiSeriesList count]-curIndex-1];
}
@end
