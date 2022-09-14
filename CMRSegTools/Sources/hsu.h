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
//  hsu.h
//  CMRSegTools
//
//  Created by Coralie Vandroux on 6/14/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <itkImage.h>
#include <itkImportImageFilter.h>
#include <itkConnectedComponentImageFilter.h>
#include <itkRescaleIntensityImageFilter.h>
#include <itkRelabelComponentImageFilter.h>
#include <itkLabelGeometryImageFilter.h>
#include <itkLabelMapToLabelImageFilter.h>
#include <itkLabelStatisticsImageFilter.h>
#include <itkBinaryImageToLabelMapFilter.h>
#include <itkBinaryContourImageFilter.h>
#include <itkFlatStructuringElement.h>
#include <itkBinaryThresholdImageFilter.h>
#include <itkBinaryDilateImageFilter.h>
#include <itkBinaryErodeImageFilter.h>
#include <itkSubtractImageFilter.h>
#include <itkCastImageFilter.h>
#include <itkAddImageFilter.h>
#include <itkExtractImageFilter.h>
#include <itkMultiplyImageFilter.h>
#include <itkVotingBinaryIterativeHoleFillingImageFilter.h>
#include <itkJoinSeriesImageFilter.h>
#include <iostream>

#import <OsiriX/ViewerController.h>
#import <OsiriX/DCMPix.h>
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/Notifications.h>
#import <OsiriX/OSIMaskROI.h>
#import "CMRSegTools.h"
#import <OsiriX/DCM/DCMObject.h>
#import <OsiriX/DCM/DCMAttributeTag.h>
#import <OsiriX/DCM/DCMAttribute.h>
typedef float PixelTypeFloat;
typedef int PixelTypeInt;
typedef itk::Image< PixelTypeFloat, 3 > ImageTypeFloat3D;
typedef itk::Image< PixelTypeInt, 3 > ImageTypeInt3D;
typedef itk::Image< PixelTypeFloat, 2 > ImageTypeFloat2D;
typedef itk::Image< PixelTypeInt, 2 > ImageTypeInt2D;
typedef itk::ImportImageFilter< PixelTypeFloat, 3 > ImportFilterTypeFloat3D;
typedef itk::ImportImageFilter< PixelTypeFloat, 2 > ImportFilterTypeFloat2D;

@interface hsu : NSObject
{
    OSIVolumeWindow *_volumeWindow;
    ImageTypeFloat3D::Pointer imageMyo;
    double meanHealthy;
    double sdHealthy;
}
@property (nonatomic, readonly, retain) OSIVolumeWindow *volumeWindow;

- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow;
- (void)compute;

@end
