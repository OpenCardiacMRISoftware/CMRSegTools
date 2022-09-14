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
/**
* Program made by Olivier Bernard, associate professor
* at Institut National des Sciences Appliquees (INSA) Lyon,
* CREATIS Laboratory,
* 69621 Villeurbanne, France,
* 11th of May 2011
* Updated 06th May 2013
*/

#include "BEAS2DPolarCoupled.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winconsistent-missing-override"
#include <vtkPolyData.h>
#include <vtkPointData.h>
#include <vtkCellArray.h>
#include <vtkDoubleArray.h>
#include <vtkImageShiftScale.h>
#include <vtkTriangle.h>
#include <vtkImageData.h>
#include <vtkMetaImageWriter.h>
#include <vtkMassProperties.h>
#include <vtkTriangleFilter.h>
#include <vtkTransform.h>
#include <vtkTransformPolyDataFilter.h>
#include <vtkPolyDataToImageStencil.h>
#include <vtkImageStencil.h>
#include <vtkMath.h>
#include <vtkQuadric.h>
#include <vtkTimerLog.h>
#include <vtkPolyLine.h>
#pragma clang diagnostic pop

#include "DoubleImageAccess.h"
#include "PointAccess.h"
#include "Vec.h"

using namespace std;

/// ----------------------------------------------------------------------
/// Class BEAS2DPolarCoupled definition
/// ----------------------------------------------------------------------
BEAS2DPolarCoupled::BEAS2DPolarCoupled() : pVolume(NULL), pMaskEndo(NULL), pMaskEpi(NULL),
    pSurfInfoEndo(NULL), pSurfInfoEpi(NULL), pMeshEndo(NULL), pMeshEpi(NULL), pMeshShape(NULL), pMeshThickness(NULL),
    pBsplineShape(NULL), pDiffBsplineShape(NULL), pBsplineThickness(NULL), pDiffBsplineThickness(NULL),
    pFeatureEndo(NULL), pFeatureEpi(NULL), pFeatureShape(NULL), pFeatureThickness(NULL), SpaceTheta(1.),
    InitCenterPoint(), NbIt(100), InitRadius(5), ColsTheta(32),
    TimestepShape(1), TimestepThickness(1), UpCubicFilterSizeShape(4), UpCubicFilterSizeThickness(4),
    ScaleShape(0), ScaleStepShape(1), ScaleColsThetaShape(32),
    ScaleThickness(0), ScaleStepThickness(1), ScaleColsThetaThickness(32),
    StepDepthIn(1.0), StepDepthOut(1.0), StepEndo(0.3),
    StepEpi(0.3), StepMyo(1.0), LocalDepth(5), contrastSignEndo(0), contrastSignEpi(0),
    UserPointsCartesian(NULL), UserPointsPolar(NULL), UserPointsThetaIndex(NULL), Save(false)
{
    pVolume = vtkUCharImageData::New();
}


BEAS2DPolarCoupled::~BEAS2DPolarCoupled()
{
    if ( pVolume )
        pVolume->Delete();
    if ( pMaskEndo )
        delete pMaskEndo;
    if ( pMaskEpi )
        delete pMaskEpi;
    if ( pMeshEndo != NULL )
        delete pMeshEndo;
    if ( pMeshEpi != NULL )
        delete pMeshEpi;
    if ( pMeshShape != NULL )
        delete pMeshShape;
    if ( pMeshThickness != NULL )
        delete pMeshThickness;
    if ( pSurfInfoEndo != NULL )
        delete pSurfInfoEndo;
    if ( pSurfInfoEpi != NULL )
        delete pSurfInfoEpi;
    if ( pBsplineShape != NULL )
        delete pBsplineShape;
    if ( pDiffBsplineShape != NULL )
        delete pDiffBsplineShape;
    if ( pBsplineThickness != NULL )
        delete pBsplineThickness;
    if ( pDiffBsplineThickness != NULL )
        delete pDiffBsplineThickness;
    if ( pFeatureEndo != NULL )
        delete pFeatureEndo;
    if ( pFeatureEpi != NULL )
        delete pFeatureEpi;
    if ( pFeatureShape != NULL )
        delete pFeatureShape;
    if ( pFeatureThickness != NULL )
        delete pFeatureThickness;
}


void BEAS2DPolarCoupled::SetInputVolume( vtkImageData *input )
{

    /// Convert volume to PixelType (normally unsigned char) values defined between 0 and 255
    if ( input->GetScalarType() != VTK_UNSIGNED_CHAR )
    {
        double min = input->GetScalarRange()[0];
        double max = input->GetScalarRange()[1];
        double diff = max-min;
        double slope = 255.0/diff;
        double inter = -slope*min;
        double shift = inter/slope;
        vtkImageShiftScale *shifter = vtkImageShiftScale::New();
        shifter->SetShift(shift);
        shifter->SetScale(slope);
        shifter->SetInputData(input);
        shifter->ReleaseDataFlagOff();
        shifter->SetOutputScalarTypeToUnsignedChar();
        shifter->Update();
        pVolume->CopyImage(shifter->GetOutput());
    }
    else
        pVolume->CopyImage(input);

}


void BEAS2DPolarCoupled::SetInitialMaskEndo( DoubleImageAccess input )
{
    this->pMaskEndo = new DoubleImageAccess(input);
}


void BEAS2DPolarCoupled::SetInitialMaskEpi( DoubleImageAccess input )
{
    this->pMaskEpi = new DoubleImageAccess(input);
}


void BEAS2DPolarCoupled::SetInitialVtkMeshEndo( vtkPoints *input )
{
    this->pMaskEndo = new DoubleImageAccess(1, ColsTheta);
    int nbPoints = input->GetNumberOfPoints();
    for (int i=0; i<nbPoints; i++){
        double pos[3];
        input->GetPoint(i,pos);
        (*this->pMaskEndo)(0,i) = pos[0];
    }
}


void BEAS2DPolarCoupled::SetInitialVtkMeshEpi( vtkPoints *input )
{
    this->pMaskEpi = new DoubleImageAccess(1, ColsTheta);
    int nbPoints = input->GetNumberOfPoints();
    for (int i=0; i<nbPoints; i++){
        double pos[3];
        input->GetPoint(i,pos);
        (*this->pMaskEpi)(0,i) = pos[0];
    }
}


vtkPoints* BEAS2DPolarCoupled::GetVtkMeshEndo()
{
    vtkPoints *pts = vtkPoints::New();
    for (int i=0; i<ColsTheta; i++) {
        pts->InsertNextPoint((*pMeshEndo)(0,i),0,0);
    }
    return pts;
}


vtkPoints* BEAS2DPolarCoupled::GetVtkMeshEpi()
{
    vtkPoints *pts = vtkPoints::New();
    for (int i=0; i<ColsTheta; i++) {
        pts->InsertNextPoint((*pMeshEpi)(0,i),0,0);
    }
    return pts;
}


void BEAS2DPolarCoupled::Print( ) const
{
    if ( pVolume != NULL ) {
        cout << "input volume" << endl;
        pVolume->Print(std::cout);
    }
    if ( pMaskEndo != NULL ) {
        cout << "input mask endo" << endl;
        pMaskEndo-> PrintImageInfo();
    }

    if ( pMaskEpi != NULL ) {
        cout << "input mask epi" << endl;
        pMaskEpi-> PrintImageInfo();
    }
    cout << "-> maximum number of iterations = " << NbIt << endl;
    cout << "-> initial radius = " << InitRadius << endl;
    cout << "-> ";
    InitCenterPoint.Print();
    cout << "-> theta samples = " << ColsTheta << endl;
}


void BEAS2DPolarCoupled::SetScale( int valShape, int valThickness )
{
    ///
    ScaleShape = valShape;
    if ( ScaleShape > 3 )
        ScaleShape = 3;
    ScaleStepShape = (int)(std::pow(2.,ScaleShape));
    ///
    ScaleThickness = valThickness;
    if ( ScaleThickness > 4 )
        ScaleThickness = 4;
    ScaleStepThickness = (int)(std::pow(2.,ScaleThickness));
}


void BEAS2DPolarCoupled::SetInitialRadius(double radiusEndo, double radiusEpi)
{
    if ( this->pMaskEndo != NULL )
        delete this->pMaskEndo;
    if ( this->pMaskEpi != NULL )
        delete this->pMaskEpi;
    this->pMaskEndo = new DoubleImageAccess(1, ColsTheta,radiusEndo);
    this->pMaskEpi = new DoubleImageAccess(1, ColsTheta,radiusEpi);
}


void BEAS2DPolarCoupled::SetUserPoints(vtkPoints *upCartesian)
{
    /// Create/reset the existing user points
    if ( this->UserPointsCartesian == NULL)
    {
        this->UserPointsCartesian = vtkPoints::New();
        this->UserPointsPolar = vtkPoints::New();
        this->UserPointsThetaIndex = vtkPoints::New();
    }
    this->UserPointsCartesian->Reset();
    this->UserPointsPolar->Reset();
    this->UserPointsThetaIndex->Reset();

    /// Set the points in cartesian coordinates
    this->UserPointsCartesian->DeepCopy(upCartesian);

}


void BEAS2DPolarCoupled::InitializeStructures()
{

    ScaleColsThetaShape = ColsTheta / ScaleStepShape;
    ScaleColsThetaThickness = ColsTheta / ScaleStepThickness;
    TimestepShape = 1. / ScaleStepShape / ScaleStepShape ;
    TimestepThickness = 1. / ScaleStepThickness / ScaleStepThickness ;

    /// Generic structures
    /// save phi indexes and theta indexes to speed up the process
    IndexTheta = linspace(0,2*vtkMath::Pi()*(1-1./ColsTheta),ColsTheta);
    SpaceTheta = IndexTheta[1]-IndexTheta[0];

    CosTheta.set_size(IndexTheta.size());
    SinTheta.set_size(IndexTheta.size());
    for (int k=0;k<IndexTheta.size();k++)
    {
        CosTheta[k] = std::cos(IndexTheta[k]);
        SinTheta[k] = std::sin(IndexTheta[k]);
    }

    /// Get the corresponding BSpline filters
    InitializeBSplineFilters();

    /// Allocate pFeature structure
    if ( pFeatureEndo != NULL )
        delete pFeatureEndo;
    pFeatureEndo = new DoubleImageAccess(1,ColsTheta);

    /// Allocate pMeshInfo structure
    if ( pSurfInfoEndo != NULL )
        delete pSurfInfoEndo;
    pSurfInfoEndo = new surfInfo[ColsTheta];

    /// Allocate pMesh structure
    pMeshEndo = new DoubleImageAccess((*pMaskEndo));

    /// create X,Y,Z 2D matrices of the cartesian interface
    float px = InitCenterPoint.GetX();
    float py = InitCenterPoint.GetY();

    for (int j=0;j<ColsTheta;j++) {
        pSurfInfoEndo[j].surfX = ((*pMeshEndo)(0,j)) * CosTheta[j] + px;
        pSurfInfoEndo[j].surfY = ((*pMeshEndo)(0,j)) * SinTheta[j] + py;
    }

    /// Allocate pFeature structure
    if ( pFeatureEpi != NULL )
        delete pFeatureEpi;
    pFeatureEpi = new DoubleImageAccess(1,ColsTheta);

    /// Allocate pMeshInfo structure
    if ( pSurfInfoEpi != NULL )
        delete pSurfInfoEpi;
    pSurfInfoEpi = new surfInfo[ColsTheta];

    /// Allocate pMesh structure
    pMeshEpi = new DoubleImageAccess((*pMaskEpi));

    /// create X,Y,Z 2D matrices of the cartesian interface
    px = InitCenterPoint.GetX();
    py = InitCenterPoint.GetY();

    for (int j=0;j<ColsTheta;j++) {
        pSurfInfoEpi[j].surfX = ((*pMeshEpi)(0,j)) * CosTheta[j] + px;
        pSurfInfoEpi[j].surfY = ((*pMeshEpi)(0,j)) * SinTheta[j] + py;
    }

    /// Allocate pMesh, pFeature and pBspline structures for shape/thickness
    pMeshShape = new DoubleImageAccess(1,ColsTheta);
    pMeshThickness = new DoubleImageAccess(1,ColsTheta);

    if ( pFeatureShape != NULL )
        delete pFeatureShape;
    pFeatureShape = new DoubleImageAccess(1,ColsTheta);

    if ( pFeatureThickness != NULL )
        delete pFeatureThickness;
    pFeatureThickness = new DoubleImageAccess(1,ColsTheta);

    if ( pBsplineShape != NULL )
        delete pBsplineShape;
    pBsplineShape = new DoubleImageAccess(1,ScaleColsThetaShape);

    if ( pBsplineThickness != NULL )
        delete pBsplineThickness;
    pBsplineThickness = new DoubleImageAccess(1,ScaleColsThetaThickness);

    /// Allocate pDiffBspline structure
    if ( pDiffBsplineShape != NULL )
        delete pDiffBsplineShape;
    pDiffBsplineShape = new DoubleImageAccess(1,ScaleColsThetaShape);

    if ( pDiffBsplineThickness != NULL )
        delete pDiffBsplineThickness;
    pDiffBsplineThickness = new DoubleImageAccess(1,ScaleColsThetaThickness);

    /// Force Bspline coefficients to match the pMesh
    CreateBSplineFromMesh();

    /// Initialize the mesh normals and curvature
    ComputeNormalMeshAndCurvature();

    /// Lastly define the sign of the local contrast
    EstimateLocalContrastSign();

    if ( this->UserPointsCartesian != NULL) {
        /// Arrange the user point
        cout << "GenerateUserPointsStructures" << endl;
        this->GenerateUserPointsStructures();
    }

}


void BEAS2DPolarCoupled::InitializeBSplineFilters()
{

    /// Optimized Indices for Shape
    vec indiceUpWeight;
    switch (ScaleShape)
    {
        case 0:
            CubicFilterShape = "0.1667 0.6667 0.1667";
            indiceUpWeight = "0";
            break;
        case 1:
            CubicFilterShape = "0.0208 0.1667 0.4792 0.6667 0.4792 0.1667 0.0208";
            indiceUpWeight = "0 0.5";
            break;
        case 2:
            CubicFilterShape = "0.0026 0.0208 0.0703 0.1667 0.3151 0.4792 0.6120 0.6667 0.6120 0.4792 0.3151 0.1667 0.0703 0.0208 0.0026";
            indiceUpWeight = "0 0.25 0.50 0.75";
            break;
        case 3:
            CubicFilterShape = "3.2552e-004 0.0026 0.0088 0.0208 0.0407 0.0703 0.1117 0.1667 0.2360 0.3151 0.3981 0.4792 0.5524 0.6120 0.6520 0.6667 0.6520 0.6120 0.5524 0.4792 0.3981 0.3151 0.2360 0.1667 0.1117 0.0703 0.0407 0.0208 0.0088 0.0026 3.2552e-004";
            indiceUpWeight = "0 0.125 0.250 0.375 0.500 0.625 0.750 0.875";
            break;
        case 4:
            CubicFilterShape = "4.0690e-005 3.2552e-004 0.0011 0.0026 0.0051 0.0088 0.0140 0.0208 0.0297 0.0407 0.0542 0.0703 0.0894 0.1117 0.1373 0.1667 0.1997 0.2360 0.2747 0.3151 0.3565 0.3981 0.4392 0.4792 0.5171 0.5524 0.5843 0.6120 0.6348 0.6520 0.6629 0.6667 0.6629 0.6520 0.6348 0.6120 0.5843 0.5524 0.5171 0.4792 0.4392 0.3981 0.3565 0.3151 0.2747 0.2360 0.1997 0.1667 0.1373 0.1117 0.0894 0.0703 0.0542 0.0407 0.0297 0.0208 0.0140 0.0088 0.0051 0.0026 0.0011 3.2552e-004 4.0690e-005";
            indiceUpWeight = "0 0.0625 0.125 0.1875 0.250 0.3125 0.375 0.4375 0.500 0.5625 0.625 0.6875 0.750 0.8125 0.875 0.9375";
            break;
            /// TODO...
        default:
            break;
    }

    /// Compute UpCubicFilter
    UpCubicFilterShape.set_size(4*indiceUpWeight.size());
    for (int k=0; k<ScaleStepShape; k++)
    {
            double w=indiceUpWeight[k];
            for (int j=0; j<4; j++)
            {
                UpCubicFilterShape[3+k*4] = (1.0 / 6.0) * w * w * w;
                UpCubicFilterShape[0+k*4] = (1.0 / 6.0) + (1.0 / 2.0) * w * (w - 1.0) - UpCubicFilterShape[3+k*4];
                UpCubicFilterShape[2+k*4] = w + UpCubicFilterShape[0+k*4] - 2.0 * UpCubicFilterShape[3+k*4];
                UpCubicFilterShape[1+k*4] = 1.0 - UpCubicFilterShape[0+k*4] - UpCubicFilterShape[2+k*4] - UpCubicFilterShape[3+k*4];
            }
    }

    /// Compute fix index vector called during multiscale operations
    int size = CubicFilterShape.length();
    IndexRowShape.set_size( size * ScaleColsThetaShape );
    for ( int n=0; n<ScaleColsThetaShape; n++ )
    {
        int x = n*(int)(std::pow(2.,ScaleShape));
        int i = x - size / 2;
        for ( int k=0; k<size; k++ )
        {
            if ( i < 0 )
                IndexRowShape[n*size+k] = i+ColsTheta;
            else
                IndexRowShape[n*size+k] = i;
            if ( i >= ColsTheta )
                IndexRowShape[n*size+k] = i-ColsTheta;
            i++;
        }
    }

    /// Upsampling part
    /// Compute fix index vector called during upsampling operations
    IndexUpRowShape.set_size( UpCubicFilterSizeShape * ScaleColsThetaShape );
    for ( int n=0; n<ScaleColsThetaShape; n++ )
    {
        int i = n-1;
        for ( int k=0; k<UpCubicFilterSizeShape; k++ )
        {
            if ( i < 0 )
                IndexUpRowShape[n*UpCubicFilterSizeShape+k] = i+ScaleColsThetaShape;
            else
                IndexUpRowShape[n*UpCubicFilterSizeShape+k] = i;
            if ( i >= ScaleColsThetaShape )
                IndexUpRowShape[n*UpCubicFilterSizeShape+k] = i-ScaleColsThetaShape;
            i++;
        }
    }

    /// Optimized Indices for Thickness
    switch (ScaleThickness)
    {
        case 0:
            CubicFilterThickness = "0.1667 0.6667 0.1667";
            indiceUpWeight = "0";
            break;
        case 1:
            CubicFilterThickness = "0.0208 0.1667 0.4792 0.6667 0.4792 0.1667 0.0208";
            indiceUpWeight = "0 0.5";
            break;
        case 2:
            CubicFilterThickness = "0.0026 0.0208 0.0703 0.1667 0.3151 0.4792 0.6120 0.6667 0.6120 0.4792 0.3151 0.1667 0.0703 0.0208 0.0026";
            indiceUpWeight = "0 0.25 0.50 0.75";
            break;
        case 3:
            CubicFilterThickness = "3.2552e-004 0.0026 0.0088 0.0208 0.0407 0.0703 0.1117 0.1667 0.2360 0.3151 0.3981 0.4792 0.5524 0.6120 0.6520 0.6667 0.6520 0.6120 0.5524 0.4792 0.3981 0.3151 0.2360 0.1667 0.1117 0.0703 0.0407 0.0208 0.0088 0.0026 3.2552e-004";
            indiceUpWeight = "0 0.125 0.250 0.375 0.500 0.625 0.750 0.875";
            break;
        case 4:
            CubicFilterThickness = "4.0690e-005 3.2552e-004 0.0011 0.0026 0.0051 0.0088 0.0140 0.0208 0.0297 0.0407 0.0542 0.0703 0.0894 0.1117 0.1373 0.1667 0.1997 0.2360 0.2747 0.3151 0.3565 0.3981 0.4392 0.4792 0.5171 0.5524 0.5843 0.6120 0.6348 0.6520 0.6629 0.6667 0.6629 0.6520 0.6348 0.6120 0.5843 0.5524 0.5171 0.4792 0.4392 0.3981 0.3565 0.3151 0.2747 0.2360 0.1997 0.1667 0.1373 0.1117 0.0894 0.0703 0.0542 0.0407 0.0297 0.0208 0.0140 0.0088 0.0051 0.0026 0.0011 3.2552e-004 4.0690e-005";
            indiceUpWeight = "0 0.0625 0.125 0.1875 0.250 0.3125 0.375 0.4375 0.500 0.5625 0.625 0.6875 0.750 0.8125 0.875 0.9375";
            break;
            /// TODO...
            /// TODO...
        default:
            break;
    }

    /// Compute UpCubicFilter
    UpCubicFilterThickness.set_size(4*indiceUpWeight.size());
    for (int k=0; k<ScaleStepThickness; k++)
    {
            double w=indiceUpWeight[k];
            for (int j=0; j<4; j++)
            {
                UpCubicFilterThickness[3+k*4] = (1.0 / 6.0) * w * w * w;
                UpCubicFilterThickness[0+k*4] = (1.0 / 6.0) + (1.0 / 2.0) * w * (w - 1.0) - UpCubicFilterThickness[3+k*4];
                UpCubicFilterThickness[2+k*4] = w + UpCubicFilterThickness[0+k*4] - 2.0 * UpCubicFilterThickness[3+k*4];
                UpCubicFilterThickness[1+k*4] = 1.0 - UpCubicFilterThickness[0+k*4] - UpCubicFilterThickness[2+k*4] - UpCubicFilterThickness[3+k*4];
            }
    }

    /// Compute fix index vector called during multiscale operations
    size = CubicFilterThickness.length();
    IndexRowThickness.set_size( size * ScaleColsThetaThickness );
    for ( int n=0; n<ScaleColsThetaThickness; n++ )
    {
        int x = n*(int)(std::pow(2.,ScaleThickness));
        int i = x - size / 2;
        for ( int k=0; k<size; k++ )
        {
            if ( i < 0 )
                IndexRowThickness[n*size+k] = i+ColsTheta;
            else
                IndexRowThickness[n*size+k] = i;
            if ( i >= ColsTheta )
                IndexRowThickness[n*size+k] = i-ColsTheta;
            i++;
        }
    }

    /// Upsampling part
    /// Compute fix index vector called during upsampling operations
    IndexUpRowThickness.set_size( UpCubicFilterSizeThickness * ScaleColsThetaThickness );
    for ( int n=0; n<ScaleColsThetaThickness; n++ )
    {
        int i = n-1;
        for ( int k=0; k<UpCubicFilterSizeThickness; k++ )
        {
            if ( i < 0 )
                IndexUpRowThickness[n*UpCubicFilterSizeThickness+k] = i+ScaleColsThetaThickness;
            else
                IndexUpRowThickness[n*UpCubicFilterSizeThickness+k] = i;
            if ( i >= ScaleColsThetaThickness )
                IndexUpRowThickness[n*UpCubicFilterSizeThickness+k] = i-ScaleColsThetaThickness;
            i++;
        }
    }

}


bool BEAS2DPolarCoupled::Convergence()
{
    return false;
}


void BEAS2DPolarCoupled::ReUpdate()
{

    if ( pMeshShape == NULL )
        return;

    /// main loop
    this->CurrentIt = 0; /// to access current It from other scopes
    bool test = false;
    while ( ( test == false ) && ( CurrentIt < NbIt ) )
    {

        //std::cout << k << std::endl;
        ComputeFeatureImage();
        if( this->UserPointsCartesian != NULL){
                ComputeUserPenalty();
        }
        ComputeVariationOfBspline();
        UpdateStructures();
        test = Convergence();
        this->CurrentIt++;
    }

}


void BEAS2DPolarCoupled::Update()
{

    if ( pVolume == NULL )
        return;

    /// First: inititialize structures
    InitializeStructures();

    /// main loop
    this->CurrentIt = 0; /// to access current It from other scopes
    bool test = false;
    while ( ( test == false ) && ( CurrentIt < NbIt ) )
    {

        //std::cout << k << std::endl;
        ComputeFeatureImage();
        if ( this->UserPointsCartesian != NULL) {
                ComputeUserPenalty();
        }
        ComputeVariationOfBspline();
        UpdateStructures();
        test = Convergence();
        this->CurrentIt++;
    }
}


void BEAS2DPolarCoupled::CreateBSplineFromMesh()
{

    int factRow = 1;

    ///Shape
    int factCol = ColsTheta/pBsplineShape->GetCols();
    for ( int i=0; i<pBsplineShape->GetRows(); i++ ) {
        for ( int j=0; j<pBsplineShape->GetCols(); j++ ) {
            (*pBsplineShape)(i,j) = ((*pMeshEndo)(i*factRow,j*factCol) +
                                            (*pMeshEpi)(i*factRow,j*factCol))/2.;
        }
    }

    ///Thickness
    factCol = ColsTheta/pBsplineThickness->GetCols();
    for ( int i=0; i<pBsplineThickness->GetRows(); i++ ) {
        for ( int j=0; j<pBsplineThickness->GetCols(); j++ ) {
            (*pBsplineThickness)(i,j) = ((*pMeshEpi)(i*factRow,j*factCol) -
                                            (*pMeshEndo)(i*factRow,j*factCol));
        }
    }

}


void BEAS2DPolarCoupled::ComputeVariationOfBspline()
{
    /// Set the shape and thickness features from the endo+epi coupling
    for (int j=0; j<ColsTheta; j++)
    {
        (*pFeatureShape)(0,j) = (*pFeatureEndo)(0,j) + (*pFeatureEpi)(0,j);
        (*pFeatureThickness)(0,j) = (*pFeatureEpi)(0,j) - (*pFeatureEndo)(0,j);
    }

    /// Normalize the pFeature values
    double maxFeatureShape=0;
    double maxFeatureThickness=0;
    for (int j=0; j<ColsTheta; j++)
    {
        if (std::abs((*pFeatureShape)(0,j)) > maxFeatureShape)
            maxFeatureShape = std::abs((*pFeatureShape)(0,j));
        if (std::abs((*pFeatureThickness)(0,j)) > maxFeatureThickness)
            maxFeatureThickness = std::abs((*pFeatureThickness)(0,j));
    }
    for (int j=0; j<ColsTheta; j++) {
        (*pFeatureShape)(0,j) = (*pFeatureShape)(0,j) / maxFeatureShape;
        (*pFeatureThickness)(0,j) = (*pFeatureThickness)(0,j) / maxFeatureThickness;
    }

    /// Penalize wall thickness
    for (int j=0; j<ColsTheta; j++)
    {
        double val = 0.5*((*pMeshEpi)(0,j)-(*pMeshEndo)(0,j));
        if (val<1) {
            (*pFeatureThickness)(0,j) = (*pFeatureThickness)(0,j) + (1-val);
        }
    }
    maxFeatureThickness=0;
    for (int j=0; j<ColsTheta; j++)
    {
        if (std::abs((*pFeatureThickness)(0,j)) > maxFeatureThickness)
            maxFeatureThickness = std::abs((*pFeatureThickness)(0,j));
    }
    for (int j=0; j<ColsTheta; j++) {
        (*pFeatureThickness)(0,j) = (*pFeatureThickness)(0,j) / maxFeatureThickness;
    }

    ///Shape
    /// Compute the corresponding pBspline coefficient variation (only convolution along 1 row)
    DownSampleVector( pFeatureShape->get_row_(0), 1, pDiffBsplineShape->get_row_(0), ScaleColsThetaShape, CubicFilterShape, IndexRowShape );

    /// Finally update pBspline coefficients
    (*pBsplineShape) = (*pBsplineShape) + (*pDiffBsplineShape) * TimestepShape;

    ///Thickness
    /// Compute the corresponding pBspline coefficient variation (only convolution along 1 row)
    DownSampleVector( pFeatureThickness->get_row_(0), 1, pDiffBsplineThickness->get_row_(0), ScaleColsThetaThickness, CubicFilterThickness, IndexRowThickness );

    /// Finally update pBspline coefficients
    (*pBsplineThickness) = (*pBsplineThickness) + (*pDiffBsplineThickness) * TimestepThickness;
}


void BEAS2DPolarCoupled::DownSampleVector( const double *inVec, int inRows, double *outVec, int outSize, vec cubicFilter, ivec indexRow )
{

    int size = cubicFilter.length();
    for ( int n=0; n<outSize; n++ )
    {
        double w=0;
        for ( int k=0; k<size; k++ )
            w += cubicFilter[k] * ( *(inVec+(indexRow[n*size+k])*inRows) );
        ( *(outVec+n*inRows) ) = w;
    }

}


void BEAS2DPolarCoupled::UpdateStructures()
{
    ///Shape
    /// Compute the corresponding pBspline coefficient variation
    UpSampleVector( pBsplineShape->get_row_(0), 1, pMeshShape->get_row_(0), ColsTheta, UpCubicFilterShape,UpCubicFilterSizeShape, IndexUpRowShape,ScaleStepShape);

    ///Thickness
    /// Compute the corresponding pBspline coefficient variation
    UpSampleVector( pBsplineThickness->get_row_(0), 1, pMeshThickness->get_row_(0), ColsTheta, UpCubicFilterThickness,UpCubicFilterSizeThickness, IndexUpRowThickness,ScaleStepThickness);

    /// Generate the endo and epi interfaces
    for(int j=0; j<ColsTheta; j++)
    {
        (*pMeshEndo)(0,j) = (*pMeshShape)(0,j)-0.5*(*pMeshThickness)(0,j);
        (*pMeshEpi)(0,j) = (*pMeshShape)(0,j)+0.5*(*pMeshThickness)(0,j);
    }
    /// Rotate the orientation axis
    float px = InitCenterPoint.GetX();
    float py = InitCenterPoint.GetY();

    for (int j=0;j<ColsTheta;j++) {
        ///Endo
        pSurfInfoEndo[j].surfX = ((*pMeshEndo)(0,j)) * CosTheta[j] + px;
        pSurfInfoEndo[j].surfY = ((*pMeshEndo)(0,j)) * SinTheta[j] + py;
        ///Epi
        pSurfInfoEpi[j].surfX = ((*pMeshEpi)(0,j)) * CosTheta[j] + px;
        pSurfInfoEpi[j].surfY = ((*pMeshEpi)(0,j)) * SinTheta[j] + py;
    }

}


void BEAS2DPolarCoupled::UpSampleVector( const double *inVec, int inRows, double *outVec, int outSize, vec upCubicFilter, int upCubicFilterSize, ivec  indexUpRow, int scaleStep)
{
    /// then loop over normal cells
    for ( int n=0; n<outSize; n++ )
    {
        double w=0;
        int pad1 = (int)(n%scaleStep)*upCubicFilterSize;
        int pad2 = (int)(std::floor(n/double(scaleStep)))*upCubicFilterSize;
        for ( int k=0; k<upCubicFilterSize; k++ )
            w += upCubicFilter[pad1+k] * ( *(inVec+(indexUpRow[pad2+k])*inRows) );
        ( *(outVec+n*inRows) ) = w;
    }
}


void BEAS2DPolarCoupled::ComputeNormalMeshAndCurvature()
{
    int index;
    double norm;

    ///Endo
    //Normal Vector Computation
    /// index (0,0) ///
    index = 0;
    pSurfInfoEndo[index].drhodtheta = ((*pMeshEndo)(0,1)-(*pMeshEndo)(0,ColsTheta-1))/2/SpaceTheta;
    pSurfInfoEndo[index].surfTangentThetaX = pSurfInfoEndo[index].drhodtheta *CosTheta[0] - ((*pMeshEndo)(0,0))*SinTheta[0];
    pSurfInfoEndo[index].surfTangentThetaY = pSurfInfoEndo[index].drhodtheta *SinTheta[0] + ((*pMeshEndo)(0,0))*CosTheta[0];
    pSurfInfoEndo[index].surfTangentThetaZ = 0;

    pSurfInfoEndo[index].surfNormalX = pSurfInfoEndo[index].surfTangentThetaY;
    pSurfInfoEndo[index].surfNormalY = -pSurfInfoEndo[index].surfTangentThetaX;
    pSurfInfoEndo[index].surfNormalZ = 0;

    norm = std::sqrt( pSurfInfoEndo[index].surfNormalX*pSurfInfoEndo[index].surfNormalX + pSurfInfoEndo[index].surfNormalY*pSurfInfoEndo[index].surfNormalY);
    pSurfInfoEndo[index].surfNormalX = pSurfInfoEndo[index].surfNormalX / norm;
    pSurfInfoEndo[index].surfNormalY = pSurfInfoEndo[index].surfNormalY / norm;

    /// index (0,ColsTheta-1) ///
    index = (ColsTheta-1);
    pSurfInfoEndo[index].drhodtheta = ((*pMeshEndo)(0,0)-(*pMeshEndo)(0,ColsTheta-2))/2/SpaceTheta;
    pSurfInfoEndo[index].surfTangentThetaX = pSurfInfoEndo[index].drhodtheta *CosTheta[ColsTheta-1] - ((*pMeshEndo)(0,ColsTheta-1))*SinTheta[ColsTheta-1];
    pSurfInfoEndo[index].surfTangentThetaY = pSurfInfoEndo[index].drhodtheta *SinTheta[ColsTheta-1] + ((*pMeshEndo)(0,ColsTheta-1))*CosTheta[ColsTheta-1];
    pSurfInfoEndo[index].surfTangentThetaZ = 0;

    pSurfInfoEndo[index].surfNormalX = pSurfInfoEndo[index].surfTangentThetaY;
    pSurfInfoEndo[index].surfNormalY = -pSurfInfoEndo[index].surfTangentThetaX;
    pSurfInfoEndo[index].surfNormalZ = 0;

    norm = std::sqrt( pSurfInfoEndo[index].surfNormalX*pSurfInfoEndo[index].surfNormalX + pSurfInfoEndo[index].surfNormalY*pSurfInfoEndo[index].surfNormalY);
    pSurfInfoEndo[index].surfNormalX = pSurfInfoEndo[index].surfNormalX / norm;
    pSurfInfoEndo[index].surfNormalY = pSurfInfoEndo[index].surfNormalY / norm;


    /// main loop ///
    for ( int j=1; j<(ColsTheta-1); j++ ) {
        int index = j;
        pSurfInfoEndo[index].drhodtheta = ((*pMeshEndo)(0,j+1)-(*pMeshEndo)(0,j-1))/2/SpaceTheta;
        /// normal derivative vectors computation
        pSurfInfoEndo[index].surfTangentThetaX = pSurfInfoEndo[index].drhodtheta *CosTheta[j] - ((*pMeshEndo)(0,j))*SinTheta[j];
        pSurfInfoEndo[index].surfTangentThetaY = pSurfInfoEndo[index].drhodtheta *SinTheta[j] + ((*pMeshEndo)(0,j))*CosTheta[j];
        pSurfInfoEndo[index].surfTangentThetaZ = 0;

        pSurfInfoEndo[index].surfNormalX = pSurfInfoEndo[index].surfTangentThetaY;
        pSurfInfoEndo[index].surfNormalY = -pSurfInfoEndo[index].surfTangentThetaX;
        pSurfInfoEndo[index].surfNormalZ = 0;

        norm = std::sqrt( pSurfInfoEndo[index].surfNormalX*pSurfInfoEndo[index].surfNormalX + pSurfInfoEndo[index].surfNormalY*pSurfInfoEndo[index].surfNormalY);
        pSurfInfoEndo[index].surfNormalX = pSurfInfoEndo[index].surfNormalX / norm;
        pSurfInfoEndo[index].surfNormalY = pSurfInfoEndo[index].surfNormalY / norm;
    }

    ///Epi
    //Normal Vector Computation
    /// index (0,0) ///
    index = 0;
    pSurfInfoEpi[index].drhodtheta = ((*pMeshEpi)(0,1)-(*pMeshEpi)(0,ColsTheta-1))/2/SpaceTheta;
    pSurfInfoEpi[index].surfTangentThetaX = pSurfInfoEpi[index].drhodtheta *CosTheta[0] - ((*pMeshEpi)(0,0))*SinTheta[0];
    pSurfInfoEpi[index].surfTangentThetaY = pSurfInfoEpi[index].drhodtheta *SinTheta[0] + ((*pMeshEpi)(0,0))*CosTheta[0];
    pSurfInfoEpi[index].surfTangentThetaZ = 0;

    pSurfInfoEpi[index].surfNormalX = pSurfInfoEpi[index].surfTangentThetaY;
    pSurfInfoEpi[index].surfNormalY = -pSurfInfoEpi[index].surfTangentThetaX;
    pSurfInfoEpi[index].surfNormalZ = 0;

    norm = std::sqrt( pSurfInfoEpi[index].surfNormalX*pSurfInfoEpi[index].surfNormalX + pSurfInfoEpi[index].surfNormalY*pSurfInfoEpi[index].surfNormalY);
    pSurfInfoEpi[index].surfNormalX = pSurfInfoEpi[index].surfNormalX / norm;
    pSurfInfoEpi[index].surfNormalY = pSurfInfoEpi[index].surfNormalY / norm;

    /// index (0,ColsTheta-1) ///
    index = (ColsTheta-1);
    pSurfInfoEpi[index].drhodtheta = ((*pMeshEpi)(0,0)-(*pMeshEpi)(0,ColsTheta-2))/2/SpaceTheta;
    pSurfInfoEpi[index].surfTangentThetaX = pSurfInfoEpi[index].drhodtheta *CosTheta[ColsTheta-1] - ((*pMeshEpi)(0,ColsTheta-1))*SinTheta[ColsTheta-1];
    pSurfInfoEpi[index].surfTangentThetaY = pSurfInfoEpi[index].drhodtheta *SinTheta[ColsTheta-1] + ((*pMeshEpi)(0,ColsTheta-1))*CosTheta[ColsTheta-1];
    pSurfInfoEpi[index].surfTangentThetaZ = 0;

    pSurfInfoEpi[index].surfNormalX = pSurfInfoEpi[index].surfTangentThetaY;
    pSurfInfoEpi[index].surfNormalY = -pSurfInfoEpi[index].surfTangentThetaX;
    pSurfInfoEpi[index].surfNormalZ = 0;

    norm = std::sqrt( pSurfInfoEpi[index].surfNormalX*pSurfInfoEpi[index].surfNormalX + pSurfInfoEpi[index].surfNormalY*pSurfInfoEpi[index].surfNormalY);
    pSurfInfoEpi[index].surfNormalX = pSurfInfoEpi[index].surfNormalX / norm;
    pSurfInfoEpi[index].surfNormalY = pSurfInfoEpi[index].surfNormalY / norm;


    /// main loop ///
    for ( int j=1; j<(ColsTheta-1); j++ ) {
        int index = j;
        pSurfInfoEpi[index].drhodtheta = ((*pMeshEpi)(0,j+1)-(*pMeshEpi)(0,j-1))/2/SpaceTheta;
        /// normal derivative vectors computation
        pSurfInfoEpi[index].surfTangentThetaX = pSurfInfoEpi[index].drhodtheta *CosTheta[j] - ((*pMeshEpi)(0,j))*SinTheta[j];
        pSurfInfoEpi[index].surfTangentThetaY = pSurfInfoEpi[index].drhodtheta *SinTheta[j] + ((*pMeshEpi)(0,j))*CosTheta[j];
        pSurfInfoEpi[index].surfTangentThetaZ = 0;

        pSurfInfoEpi[index].surfNormalX = pSurfInfoEpi[index].surfTangentThetaY;
        pSurfInfoEpi[index].surfNormalY = -pSurfInfoEpi[index].surfTangentThetaX;
        pSurfInfoEpi[index].surfNormalZ = 0;

        norm = std::sqrt( pSurfInfoEpi[index].surfNormalX*pSurfInfoEpi[index].surfNormalX + pSurfInfoEpi[index].surfNormalY*pSurfInfoEpi[index].surfNormalY);
        pSurfInfoEpi[index].surfNormalX = pSurfInfoEpi[index].surfNormalX / norm;
        pSurfInfoEpi[index].surfNormalY = pSurfInfoEpi[index].surfNormalY / norm;
    }


}


vec BEAS2DPolarCoupled::linspace(double from, double to, int points)
{

    if (points<2)
    {
        vec output(1);
        output(0)=to;
        return output;
    }
    else
    {
        vec output(points);
        double step = (to - from) / double(points-1);
        int i;
        for (i=0; i<points; i++)
            output(i) = from + i*step;
        return output;
    }

}


vtkPolyData* BEAS2DPolarCoupled::GetOutputEndo()
{

    /// Force the computation of the normal
    ComputeNormalMeshAndCurvature();

    vtkPoints *pts = vtkPoints::New();
    vtkPolyLine *polyLine =  vtkPolyLine::New();
    polyLine->GetPointIds()->SetNumberOfIds(ColsTheta+1);

    vtkDoubleArray *pointNormalsArray = vtkDoubleArray::New();
    pointNormalsArray->SetNumberOfComponents(3);
    pointNormalsArray->SetNumberOfTuples(ColsTheta);

    vtkUnsignedCharArray *colorsArray = vtkUnsignedCharArray::New();
    colorsArray->SetNumberOfComponents(3);
    colorsArray->SetName("Colors");
    colorsArray->SetNumberOfTuples(ColsTheta);

    for ( int j=0; j<ColsTheta; j++ ) {
        double p[3];
        p[0] = pSurfInfoEndo[j].surfX;
        p[1] = pSurfInfoEndo[j].surfY;
        p[2] = 0;
        vtkIdType id = pts->InsertNextPoint(p);

        /// normals
        p[0] = pSurfInfoEndo[j].surfNormalX;
        p[1] = pSurfInfoEndo[j].surfNormalY;
        p[2] = pSurfInfoEndo[j].surfNormalZ;
        pointNormalsArray->SetTuple(id,p);

        /// lines
        polyLine->GetPointIds()->SetId(j,j);

        ///colors
        double colorHSV[3]={((double) j)/((double) ColsTheta), 1.0, 1.0};
        double colorRGB[3];
        vtkMath::HSVToRGB(colorHSV, colorRGB);

        colorRGB[0]=colorRGB[0]*255;
        colorRGB[1]=colorRGB[1]*255;
        colorRGB[2]=colorRGB[2]*255;

        colorsArray->SetTuple(id, colorRGB);
    }

    polyLine->GetPointIds()->SetId(ColsTheta,0);


    /// Create and store the polydata with the points, triangles, vertices and normal information
    vtkCellArray *cells = vtkCellArray::New();
    cells->InsertNextCell(polyLine);
    vtkPolyData *polydata = vtkPolyData::New();
    polydata->SetPoints(pts);
    polydata->SetLines(cells);
    polydata->GetPointData()->SetNormals(pointNormalsArray);
    return polydata;

}

vtkPolyData* BEAS2DPolarCoupled::GetOutputEpi()
{

    /// Force the computation of the normal
    ComputeNormalMeshAndCurvature();

    vtkPoints *pts = vtkPoints::New();
    vtkPolyLine *polyLine =  vtkPolyLine::New();
    polyLine->GetPointIds()->SetNumberOfIds(ColsTheta+1);

    vtkDoubleArray *pointNormalsArray = vtkDoubleArray::New();
    pointNormalsArray->SetNumberOfComponents(3);
    pointNormalsArray->SetNumberOfTuples(ColsTheta);

    vtkUnsignedCharArray *colorsArray = vtkUnsignedCharArray::New();
    colorsArray->SetNumberOfComponents(3);
    colorsArray->SetName("Colors");
    colorsArray->SetNumberOfTuples(ColsTheta);

    for ( int j=0; j<ColsTheta; j++ ) {
        double p[3];
        p[0] = pSurfInfoEpi[j].surfX;
        p[1] = pSurfInfoEpi[j].surfY;
        p[2] = 0;
        vtkIdType id = pts->InsertNextPoint(p);

        /// normals
        p[0] = pSurfInfoEpi[j].surfNormalX;
        p[1] = pSurfInfoEpi[j].surfNormalY;
        p[2] = pSurfInfoEpi[j].surfNormalZ;
        pointNormalsArray->SetTuple(id,p);

        /// lines
        polyLine->GetPointIds()->SetId(j,j);

        ///colors
        double colorHSV[3]={((double) j)/((double) ColsTheta), 1.0, 1.0};
        double colorRGB[3];
        vtkMath::HSVToRGB(colorHSV, colorRGB);

        colorRGB[0]=colorRGB[0]*255;
        colorRGB[1]=colorRGB[1]*255;
        colorRGB[2]=colorRGB[2]*255;

        colorsArray->SetTuple(id, colorRGB);
    }

    polyLine->GetPointIds()->SetId(ColsTheta,0);


    /// Create and store the polydata with the points, triangles, vertices and normal information
    vtkCellArray *cells = vtkCellArray::New();
    cells->InsertNextCell(polyLine);
    vtkPolyData *polydata = vtkPolyData::New();
    polydata->SetPoints(pts);
    polydata->SetLines(cells);
    polydata->GetPointData()->SetNormals(pointNormalsArray);

    return polydata;

}


vtkPoints* BEAS2DPolarCoupled::GetEndoPoints()
{

    vtkPoints *pts = vtkPoints::New();
    for ( int j=0; j<this->ColsTheta; j++ )
    {
        double p[3];
        p[0] = pSurfInfoEndo[j].surfX * this->pVolume->GetSpacing()[0] +
                this->pVolume->GetOrigin()[0];
        p[1] = pSurfInfoEndo[j].surfY * this->pVolume->GetSpacing()[1] +
                this->pVolume->GetOrigin()[1];
        p[2] = this->pVolume->GetOrigin()[2];;
        pts->InsertNextPoint(p);
    }
    return pts;

}


vtkPoints* BEAS2DPolarCoupled::GetEpiPoints()
{

    vtkPoints *pts = vtkPoints::New();
    for ( int j=0; j<this->ColsTheta; j++ )
    {
        double p[3];
        p[0] = pSurfInfoEpi[j].surfX * this->pVolume->GetSpacing()[0] +
                this->pVolume->GetOrigin()[0];
        p[1] = pSurfInfoEpi[j].surfY * this->pVolume->GetSpacing()[1] +
                this->pVolume->GetOrigin()[1];
        p[2] = this->pVolume->GetOrigin()[2];;
        pts->InsertNextPoint(p);
    }
    return pts;

}


void BEAS2DPolarCoupled::EstimateLocalContrastSign()
{

    ComputeNormalMeshAndCurvature();

    /// Compute feature image
    double meanIn;
    double meanOut;

    /// Endo
    meanIn = 0;
    meanOut = 0;
    for (int j=0; j<ColsTheta; j++) {

        for (int k=0; k<LocalDepth; k++) {

            meanIn += (*pVolume)(   (int)(std::floor( pSurfInfoEndo[j].surfX-StepDepthIn*k*pSurfInfoEndo[j].surfNormalX + 0.5)),
                                    (int)(std::floor( pSurfInfoEndo[j].surfY-StepDepthIn*k*pSurfInfoEndo[j].surfNormalY + 0.5)));

            meanOut += (*pVolume)(   (int)(std::floor( pSurfInfoEndo[j].surfX+StepDepthOut*k*pSurfInfoEndo[j].surfNormalX + 0.5)),
                                     (int)(std::floor( pSurfInfoEndo[j].surfY+StepDepthOut*k*pSurfInfoEndo[j].surfNormalY + 0.5)));
        }
    }

    if (meanOut > meanIn) {
        contrastSignEndo = -1;
        //cout << "Endo: meanOut > meanIn" << endl;
    }
    else {
        contrastSignEndo = 1;
        //cout << "Endo: meanOut < meanIn" << endl;
    }

    /// Epi
    meanIn = 0;
    meanOut = 0;
    for (int j=0; j<ColsTheta; j++) {
        for (int k=0; k<LocalDepth; k++) {

            meanIn += (*pVolume)(   (int)(std::floor( pSurfInfoEpi[j].surfX-StepDepthIn*k*pSurfInfoEpi[j].surfNormalX + 0.5)),
                                    (int)(std::floor( pSurfInfoEpi[j].surfY-StepDepthIn*k*pSurfInfoEpi[j].surfNormalY + 0.5)));

            meanOut += (*pVolume)(   (int)(std::floor( pSurfInfoEpi[j].surfX+StepDepthOut*k*pSurfInfoEpi[j].surfNormalX + 0.5)),
                                     (int)(std::floor( pSurfInfoEpi[j].surfY+StepDepthOut*k*pSurfInfoEpi[j].surfNormalY + 0.5)));
        }
    }

    if ( meanOut > meanIn ) {
        contrastSignEpi = -1;
        cout << "Epi: meanOut > meanIn" << endl;
    }
    else {
        contrastSignEpi = 1;
        cout << "Epi: meanOut < meanIn" << endl;
    }

}


void BEAS2DPolarCoupled::GenerateUserPointsStructures()
{

    int NbPoints = this->UserPointsCartesian->GetNumberOfPoints();
    for ( int i=0; i<NbPoints; i++ )
    {
        ///
        double pos[3], tempTheta, tempRho, tempRhoEndo, tempRhoEpi;
        this->UserPointsCartesian->GetPoint(i,pos);
        ///
        tempTheta = std::atan2(pos[1]-this->InitCenterPoint.GetY(), pos[0]-this->InitCenterPoint.GetX());
        if(tempTheta<0)
            tempTheta+=2*vtkMath::Pi();
        ///
        tempRho = std::sqrt((pos[0]-this->InitCenterPoint.GetX())*(pos[0]-this->InitCenterPoint.GetX())
                            + (pos[1]-this->InitCenterPoint.GetY())*(pos[1]-this->InitCenterPoint.GetY()));

        ///
        this->UserPointsPolar->InsertNextPoint(tempRho, tempTheta, 0);
        ///

        int j=0;
        bool test = false;
        while ( j<(ColsTheta-1) && (test==false) )
        {
            if ( (tempTheta>=this->IndexTheta[j]) && (tempTheta<this->IndexTheta[j+1]) )
            {
                ///cout << tempRho << " " << tempTheta << endl;
                tempRhoEndo = ((*pMeshEndo)(0,(int)(j)) + (*pMeshEndo)(0,(int)(j+1)) ) / 2;
                tempRhoEpi = ((*pMeshEpi)(0,(int)(j)) + (*pMeshEpi)(0,(int)(j+1)) ) / 2;
                if (std::abs(tempRhoEndo-tempRho)<std::abs(tempRhoEpi-tempRho))
                    this->UserPointsThetaIndex->InsertNextPoint(j,j+1,-1);
                else
                    this->UserPointsThetaIndex->InsertNextPoint(j,j+1,1);

                test=true;
            }
            j++;
        }

        if ( test == false )
        {
            tempRhoEndo = ((*pMeshEndo)(0,ColsTheta-1) + (*pMeshEndo)(0,0) ) / 2;
            tempRhoEpi = ((*pMeshEpi)(0,ColsTheta-1) + (*pMeshEpi)(0,0) ) / 2;
            if (std::abs(tempRhoEndo-tempRho)<std::abs(tempRhoEpi-tempRho))
                this->UserPointsThetaIndex->InsertNextPoint(ColsTheta-1,0,-1);
            else
                this->UserPointsThetaIndex->InsertNextPoint(ColsTheta-1,0,1);
        }

        /*
        for (int j=0; j<ColsTheta-1; j++)
        {

            if ( (tempTheta>=this->IndexTheta[j]) && (tempTheta<this->IndexTheta[j+1]) )
            {
                ///cout << tempRho << " " << tempTheta << endl;
                tempRhoEndo = ((*pMeshEndo)(0,(int)(j)) + (*pMeshEndo)(0,(int)(j+1)) ) / 2;
                tempRhoEpi = ((*pMeshEpi)(0,(int)(j)) + (*pMeshEpi)(0,(int)(j+1)) ) / 2;
                if (std::abs(tempRhoEndo-tempRho)<std::abs(tempRhoEpi-tempRho))
                    this->UserPointsThetaIndex->InsertNextPoint(j,j+1,-1);
                else
                    this->UserPointsThetaIndex->InsertNextPoint(j,j+1,1);

                break;
            }

            else    /// TODO DEBUG if it is right !
            {
                tempRhoEndo = ((*pMeshEndo)(0,ColsTheta-1) + (*pMeshEndo)(0,0) ) / 2;
                tempRhoEpi = ((*pMeshEpi)(0,ColsTheta-1) + (*pMeshEpi)(0,0) ) / 2;
                if (std::abs(tempRhoEndo-tempRho)<std::abs(tempRhoEpi-tempRho))
                    this->UserPointsThetaIndex->InsertNextPoint(ColsTheta-1,0,-1);
                else
                    this->UserPointsThetaIndex->InsertNextPoint(ColsTheta-1,0,1);

                break;
            }

        }
        */

    }

}


/// User Penalty functions
void BEAS2DPolarCoupled::ComputeUserPenalty()
{

    int NbPoints = this->UserPointsCartesian->GetNumberOfPoints();
    for ( int i=0; i<NbPoints; i++ )
    {

        double pos[3];
        this->UserPointsPolar->GetPoint(i,pos);
        double index[3];
        this->UserPointsThetaIndex->GetPoint(i,index);
        ///cout << pos[0] << "  " << pos[1] << "  " << pos[2]
        ///     << index[0] << "  " << index[1] << "  " << index[2] << endl;
        if(index[2]==-1)//Endo
        {
            double tempRho = ( (*pMeshEndo)(0,(int)(index[0])) + (*pMeshEndo)(0,(int)(index[1])) ) / 2;
            (*pFeatureEndo)(0,(int)(index[0]))
                    = (pos[0]-tempRho) / TimestepShape;
            (*pFeatureEndo)(0,(int)(index[1])) = (pos[0]-tempRho) / TimestepShape;
        }
        else if(index[2]==1)//Epi
        {
            double tempRho = ( (*pMeshEpi)(0,(int)(index[0])) + (*pMeshEpi)(0,(int)(index[1])) ) / 2;
            (*pFeatureEpi)(0,(int)(index[0]))
                    = (pos[0]-tempRho) / TimestepShape;
            (*pFeatureEpi)(0,(int)(index[1])) = (pos[0]-tempRho) / TimestepShape;
        }
    }

}


