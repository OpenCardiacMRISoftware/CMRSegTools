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

#ifndef _BEAS2DPolarCoupled_h_
#define _BEAS2DPolarCoupled_h_

#include <vtkPolyData.h>
#include <vtkFloatArray.h>
#include <vtkPointData.h>
#include "DoubleImageAccess.h"
#include "PointAccess.h"
#include "Vec.h"
#include "vtkOptimizedImageData.h"

using namespace std;
typedef vtkOptimizedImageData<unsigned char> vtkUCharImageData;
typedef vtkOptimizedImageData<double> vtkDoubleImageData;

class BEAS2DPolarCoupled
{

    protected:

        /// Declaration of Attributes
        vtkUCharImageData *pVolume;
        DoubleImageAccess *pMaskEndo;
        DoubleImageAccess *pMaskEpi;
        struct surfInfo {
            double surfX;
            double surfY;
            double surfZ;
            double surfNormalX;
            double surfNormalY;
            double surfNormalZ;
            double surfTangentThetaX;
            double surfTangentThetaY;
            double surfTangentThetaZ;
            double drhodtheta;
        };
        surfInfo *pSurfInfoEndo;
        surfInfo *pSurfInfoEpi;
        DoubleImageAccess *pMeshEndo;
        DoubleImageAccess *pMeshEpi;
        DoubleImageAccess *pMeshShape;
        DoubleImageAccess *pMeshThickness;
        DoubleImageAccess *pBsplineShape;
        DoubleImageAccess *pDiffBsplineShape;
        DoubleImageAccess *pBsplineThickness;
        DoubleImageAccess *pDiffBsplineThickness;
        DoubleImageAccess *pFeatureEndo;
        DoubleImageAccess *pFeatureEpi;
        DoubleImageAccess *pFeatureShape;
        DoubleImageAccess *pFeatureThickness;

        vec IndexTheta;
        double SpaceTheta;
        ivec IndexRowShape;
        ivec IndexUpRowShape;
        ivec IndexRowThickness;
        ivec IndexUpRowThickness;
        vec CosTheta;
        vec SinTheta;
        PointAccess InitCenterPoint;
        int NbIt;
        int InitRadius;
        int ColsTheta;
        double TimestepShape;
        double TimestepThickness;
        vec CubicFilterShape;
        vec UpCubicFilterShape;
        int UpCubicFilterSizeShape;
        vec CubicFilterThickness;
        vec UpCubicFilterThickness;
        int UpCubicFilterSizeThickness;
        int ScaleShape;
        int ScaleStepShape;
        int ScaleColsThetaShape;
        int ScaleThickness;
        int ScaleStepThickness;
        int ScaleColsThetaThickness;
        double StepDepthIn;
        double StepDepthOut;
        int CurrentIt;
        double StepEndo;
        double StepEpi;
        double StepMyo;
        int LocalDepth;
        double contrastSignEndo;
        double contrastSignEpi;
        vtkPoints *UserPointsCartesian;
        vtkPoints *UserPointsPolar;
        vtkPoints *UserPointsThetaIndex;
        bool Save;

        /// Declaration of Methods
        virtual void InitializeStructures();
        void InitializeBSplineFilters();
        bool Convergence();
        void ComputeVariationOfBspline();
        void DownSampleVector( const double *inVec, int inRows, double *outVec, int outSize, vec CubicFilter, ivec indexRow  );
        void UpdateStructures();
        void UpSampleVector( const double *inVec, int inRows, double *outVec, int outSize, vec upCubicFilter, int upCubicFilterSize, ivec  indexUpRow, int scaleStep);
        void ComputeNormalMeshAndCurvature();
        void UpSampleMesh();
        void CreateBSplineFromMesh();
        vec linspace(double from, double to, int points);
        void EstimateLocalContrastSign();
        virtual void ComputeFeatureImage()=0;

    public:

        BEAS2DPolarCoupled();
        virtual ~BEAS2DPolarCoupled();

        /// Set methods
        void SetInputVolume( vtkImageData *input );
        void SetInitialMaskEndo( DoubleImageAccess input );
        void SetInitialMaskEpi( DoubleImageAccess input );
        void SetInitialVtkMeshEndo( vtkPoints *input );
        void SetInitialVtkMeshEpi( vtkPoints *input );
        void SetNumberOfIteration( int val ) { NbIt = val; }
        void SetCenterPoint( PointAccess &pt ) { InitCenterPoint.SetPoint( pt ); }
        void SetCenterPoint( double x, double y, double z ) { this->InitCenterPoint.SetPoint(x, y, z); }
        void SetCenterPoint( PointAccess pt ) { this->InitCenterPoint.SetPoint(pt); }
        void SetLocalDepth( int val ) { LocalDepth = val; }
        void SetNumberOfThetaSamples( int val ) { ColsTheta = val; }
        void SetStepEndo( double val ) { StepEndo = val; }
        void SetStepEpi( double val ) { StepEpi = val; }
        void SetScale( int valShape, int valThickness );
        void SaveResults( bool val = true ) { Save = val; }
        void SetStepDepthIn( double val ){ this->StepDepthIn = val; }
        void SetStepDepthOut( double val ){ this->StepDepthOut = val; }
        void SetInitialRadius( double radiusEndo, double radiusEpi );
        void SetUserPoints( vtkPoints *upCartesian );


        /// Get methods
        vtkPolyData *GetOutputEndo();
        vtkPolyData *GetOutputEpi();
        vtkPoints *GetEndoPoints();
        vtkPoints *GetEpiPoints();
        double GetCenterPointX() { return InitCenterPoint.GetX(); }
        double GetCenterPointY() { return InitCenterPoint.GetY(); }
        double GetCenterPointZ() { return InitCenterPoint.GetZ(); }
        PointAccess GetCenterPoint() { return InitCenterPoint; }
        int GetNumberOfThetaSamples() { return ColsTheta; }
        vec GetIndexTheta() { return this->IndexTheta; }
        double GetStepDepthIn() { return this->StepDepthIn; }
        double GetStepDepthOut() { return this->StepDepthOut; }
        DoubleImageAccess GetMeshEndo() { return (*this->pMeshEndo); }
        DoubleImageAccess GetMeshEpi() { return (*this->pMeshEpi); }
        vtkPoints* GetVtkMeshEndo();
        vtkPoints* GetVtkMeshEpi();
        DoubleImageAccess* GetpMeshEndo() { return this->pMeshEndo; }
        DoubleImageAccess* GetpMeshEpi() { return this->pMeshEpi; }


        /// Dedicated methods
        void Print() const;
        void Update();
        virtual void UpdateForEvaluation() {}
        void ReUpdate();
        void GenerateUserPointsStructures();
        void ComputeUserPenalty();

};


#endif

