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
//  HMRFBeta.h
//  CMRSegToolsPlugin
//
//  Created by Coralie Vandroux on 8/14/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "itkImage.h"
#include "itkImportImageFilter.h"
#include "itkConnectedComponentImageFilter.h"
#include "itkRescaleIntensityImageFilter.h"
#include "itkRelabelComponentImageFilter.h"
#include "itkLabelGeometryImageFilter.h"
#include "itkBinaryImageToLabelMapFilter.h"
#include "itkBinaryContourImageFilter.h"
#include "itkFlatStructuringElement.h"
#include "itkBinaryThresholdImageFilter.h"
#include "itkBinaryDilateImageFilter.h"
#include "itkBinaryErodeImageFilter.h"
#include "itkSubtractImageFilter.h"
#include "itkImageRegionConstIterator.h"
#include "itkJoinSeriesImageFilter.h"
#include "itkBinaryContourImageFilter.h"
#include "itkCastImageFilter.h"
#include "itkMultiplyImageFilter.h"
#include "itkInvertIntensityImageFilter.h"
#include "itkVotingBinaryIterativeHoleFillingImageFilter.h"
#include "itkStatisticsImageFilter.h"
#include <itkLabelStatisticsImageFilter.h>
#include <itkSubtractImageFilter.h>
#include <itkLabelContourImageFilter.h>
#include <itkThresholdImageFilter.h>
#include <iostream>
#include <algorithm>

#import <OsiriXAPI/ROI.h>
#import <OsiriXAPI/ViewerController.h>
#import <OsiriXAPI/DCMPix.h>
#import <OsiriXAPI/OSIVolumeWindow.h>
#import <OsiriXAPI/OSIROIFloatPixelData.h>
#import <OsiriXAPI/Notifications.h>
#import <OsiriXAPI/OSIMaskROI.h>
#import "CMRSegToolsPlugin.h"
#import "DCMObject.h"
#import "DCMAttributeTag.h"
#import "DCMAttribute.h"
typedef float PixelTypeFloat;
typedef int PixelTypeInt;
typedef itk::Image< PixelTypeFloat, 2 > ImageTypeFloat2D;
typedef itk::Image< PixelTypeFloat, 3 > ImageTypeFloat3D;
typedef itk::Image< PixelTypeInt, 3 > ImageTypeInt3D;
typedef itk::Image< PixelTypeInt, 2 > ImageTypeInt2D;
typedef itk::ImportImageFilter< PixelTypeFloat, 2 > ImportFilterTypeFloat2D;
typedef itk::ImportImageFilter< PixelTypeFloat, 3 > ImportFilterTypeFloat3D;
typedef itk::LabelGeometryImageFilter< ImageTypeInt3D > LabelGeometryImageFilterType;

#define DEBUG_HMRF_DEV 1 //generate an optional file
#define RATETOSTOP 20 //Initial  value of ??
#define ITMAPMAX 7 //Max iteration number of MAP loop
#define ITEMMAX 7 //Max iteration number of  EM loop
#define RATEOFCHANGEFORVOLUMEFEATURE 2
#define RATEOSSIZE 0.5
#define RATEOFNONINFARTEDNEIGHBOR 0.50
#define MINIMALRATEOFCURRENTWHITEPIXELSADDED 0.05
#define INITIALTHRESHOLD 0.8
#define MULTIPLYINGFACTOROFVOLUMEFEATURE 3
#define LOGFILEPATH "/Users/alexandrabaluta/Documents/HMRF_Results1/"

#ifdef DEBUG_HMRF_DEV
    #include <stdlib.h>
    #include <stdio.h>
    FILE* fichier;
    FILE* fichier1;
    FILE* fichier2;
    char mychar[255] ;
    int b=0;
    int aa;
    int iEM;
    int il;
    int imageDepth;
    int indexToShow=14;
    bool labelChanged=true;
    bool labelChangedByStep=false;
    bool cleaned;
NSMutableArray *listPix;
#endif

@interface HMRFBeta : NSObject
{
    int multiplyingFactorOfVolumeFeature;
    float initialThreshold;
    double minimalRateOfCurrentWhitePixelsAdded;
    double rateOfSize;
    float rateOfNonInfartedNeighbor;
    ViewerController *viewControl;
#ifdef DEBUG_HMRF_DEV
    ViewerController *viewControl1;
#endif
    OSIVolumeWindow *_volumeWindow;
    NSPoint center;
    int ray;
    double maxMyocardium;
    double mean1,mean2,std1,std2;
    double U;
    double sumPly_0, sumPly_1, sumPlyY_0, sumPlyY_1, sumPlyYmu_0, sumPlyYmu_1;
    double rateToStop;
    float nonInfarctNeighboor;
    int slicesNumber;
    bool labelChanged;
    bool stopEmForVolumeFeature;
    int rateOfChangeForVolumefeature;
    bool cleaned;
    int countCleaned;
    int imageDepth;
    bool multiplywithmyo;
    std::vector<double> ply_0,ply_1;
    std::vector<double> imageVector;
    std::vector<double> myoSize;
    std::vector<int> numberWhitePixel;
    int time;
    ImageTypeFloat3D::Pointer image;
    ImageTypeInt3D::Pointer myocardium;
    ImageTypeFloat3D::Pointer myocardiumPolar;
    ImageTypeFloat3D::Pointer label;
    ImageTypeFloat3D::Pointer labelCart;
    ImageTypeFloat3D::Pointer noReflowCart;
    ImageTypeFloat3D::Pointer imageCartesian;
    int itMAP;
    int itEM;
}
@property (nonatomic, readonly, retain) OSIVolumeWindow *volumeWindow;

- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow;
- (void)compute;

@end