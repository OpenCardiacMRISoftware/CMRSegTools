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
//  gaussianMixtureModel.h
//  CMRSegTools
//
//  Created by Coralie Vandroux on 8/13/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <Foundation/Foundation.h>
//#include <vector>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winconsistent-missing-override"
#import <vtkImageImport.h>
#import <vtkMetaImageReader.h>
#include <vtkImageData.h>
#include "vtkOptimizedImageData.h"
#include <vtkImageShiftScale.h>
#pragma clang diagnostic pop
//#include <stdlib.h>
#include <itkImage.h>
#include <itkImportImageFilter.h>
#include <itkConnectedComponentImageFilter.h>
#include <itkRescaleIntensityImageFilter.h>
#include <itkRelabelComponentImageFilter.h>
#include <itkLabelGeometryImageFilter.h>
#include <itkBinaryImageToLabelMapFilter.h>
#include <itkBinaryContourImageFilter.h>
#include <itkFlatStructuringElement.h>
#include <itkBinaryThresholdImageFilter.h>
#include <itkBinaryDilateImageFilter.h>
#include <itkBinaryErodeImageFilter.h>
#include <itkSubtractImageFilter.h>
#include <iostream>
#include <algorithm>

#import <OsiriX/ViewerController.h>
#import <OsiriX/DCMPix.h>
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/OSIROIFloatPixelData.h>
#import <OsiriX/OSIMaskROI.h>
#import "CMRSegTools.h"
#import <OsiriX/DCM/DCMObject.h>
#import <OsiriX/DCM/DCMAttributeTag.h>
#import <OsiriX/DCM/DCMAttribute.h>
#import "OsiriX+CMRSegTools.h"


typedef vtkOptimizedImageData<unsigned char> vtkUCharImageData;

@interface gaussianMixtureModel : NSObject {
    OSIVolumeWindow *_volumeWindow;
    
    NSString* type;
    double mean1,mean2,var1,var2,w1,w2;
    double nmean1,nmean2,nvar1,nvar2,nw1,nw2;
    double sumPDF1, sumPDF2;
    double sumPDF1x, sumPDF2x;
    double sumPDF1x2, sumPDF2x2;
    std::vector<int> pixel;
    std::vector<double> PDF1,PDF2;
}

@property (nonatomic, readonly, retain) OSIVolumeWindow *volumeWindow;

- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow;
- (void)compute:(NSString*)TypeOfDistribution;

@end
