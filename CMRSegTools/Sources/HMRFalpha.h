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
//  HMRFalpha.h
//  CMRSegTools
//
//  Created by Coralie Vandroux on 8/14/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <Foundation/Foundation.h>
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
#include <itkImageRegionConstIterator.h>
#include <itkJoinSeriesImageFilter.h>
#include <itkBinaryContourImageFilter.h>
#include <itkCastImageFilter.h>
#include <itkMultiplyImageFilter.h>
#include <itkInvertIntensityImageFilter.h>
#include <itkVotingBinaryIterativeHoleFillingImageFilter.h>
#include <itkStatisticsImageFilter.h>
#include <iostream>
#include <algorithm>

#import <OsiriX/ROI.h>
#import <OsiriX/ViewerController.h>
#import <OsiriX/DCMPix.h>
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/OSIROIFloatPixelData.h>
#import <OsiriX/Notifications.h>
#import <OsiriX/OSIMaskROI.h>
#import "CMRSegTools.h"
#import <OsiriX/DCM/DCMObject.h>
#import <OsiriX/DCM/DCMAttributeTag.h>
#import <OsiriX/DCM/DCMAttribute.h>
typedef float PixelTypeFloat;
typedef int PixelTypeInt;
typedef itk::Image< PixelTypeFloat, 2 > ImageTypeFloat2D;
typedef itk::Image< PixelTypeFloat, 3 > ImageTypeFloat3D;
typedef itk::Image< PixelTypeInt, 3 > ImageTypeInt3D;
typedef itk::Image< PixelTypeInt, 2 > ImageTypeInt2D;
typedef itk::ImportImageFilter< PixelTypeFloat, 2 > ImportFilterTypeFloat2D;
typedef itk::ImportImageFilter< PixelTypeFloat, 3 > ImportFilterTypeFloat3D;
typedef itk::LabelGeometryImageFilter< ImageTypeInt3D > LabelGeometryImageFilterType;

@interface HMRFalpha : NSObject
{
    ViewerController *_viewControl;
    OSIVolumeWindow *_volumeWindow;
    NSPoint _center;
    int _ray;
    double _maxMyocardium;
    double _mean1,_mean2,_std1,_std2;
    double _U;
    double _sumPly_0, _sumPly_1, _sumPlyY_0, _sumPlyY_1, _sumPlyYmu_0, _sumPlyYmu_1;
    std::vector<double> _ply_0,_ply_1;
    std::vector<double> _imageVector;
    ImageTypeFloat3D::Pointer _image;
    ImageTypeInt3D::Pointer _myocardium;
    ImageTypeFloat3D::Pointer _myocardiumPolar;
    ImageTypeFloat3D::Pointer _label;
    ImageTypeFloat3D::Pointer _labelCart;
    ImageTypeFloat3D::Pointer _noReflowCart;
}
@property (nonatomic, readonly, retain) OSIVolumeWindow *volumeWindow;

- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow;
- (void)compute;

@end
