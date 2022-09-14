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

#include <vtkMath.h>
#include <vtkTimerLog.h>
#include <vector>
//#include "Otsu.h"
#include "Local2PhasesBEAS2DPolarCoupled.h"

using namespace std;


/// ----------------------------------------------------------------------
/// Class Local2PhasesBEAS definition
/// ----------------------------------------------------------------------
Local2PhasesBEAS2DPolarCoupled::Local2PhasesBEAS2DPolarCoupled(): pThetaImage(NULL),
    pRhoImage(NULL), MyoMean(0.), ThreshIschemic(0.)
{ }


Local2PhasesBEAS2DPolarCoupled::~Local2PhasesBEAS2DPolarCoupled()
{
    if (this->pThetaImage)
        delete this->pThetaImage;
    if (this->pRhoImage)
        delete this->pRhoImage;
    /*
    if (this->pMaskIschemic)
        delete this->pMaskIschemic;
    */
}


/// Compute specific structures to compute the feature function
void Local2PhasesBEAS2DPolarCoupled::InitializeStructures()
{

    this->BEAS2DPolarCoupled::InitializeStructures();


    int size[3];
    this->pVolume->GetDimensions(size);
    this->pThetaImage = new DoubleImageAccess(size[0],size[1]);
    this->pRhoImage = new DoubleImageAccess(size[0],size[1]);
    //this->pMaskIschemic = new DoubleImageAccess(size[0],size[1],0);

    double px = this->GetCenterPointX();
    double py = this->GetCenterPointY();
    for (int x=0; x<size[0]; x++)
    {
        for (int y=0; y<size[1]; y++)
        {
            (*this->pRhoImage)(x,y) = sqrt( (x-px)*(x-px) + (y-py)*(y-py) );
            double val = atan2(y-py,x-px);
            if (val<0)
                val = val+2*vtkMath::Pi();
            val = floor(val/(2*vtkMath::Pi()/this->GetNumberOfThetaSamples()));
            (*this->pThetaImage)(x,y) = val;
        }
    }

    /*
    /// Compute the region of interest to optimally create the different masks
    double rhoEndo = (*pMeshEndo)(0,0);
    double rhoEpi = (*pMeshEpi)(0,0);
    double maxEpi = 0.;
    for (int k=0; k<ColsTheta; k++)
    {
        if ( maxEpi < (*this->pMeshEpi)(0,k) )
            maxEpi = (*this->pMeshEpi)(0,k);
    }
    int padRegion = (int)(maxEpi) + 3;

    vector<double> listMyo;
    for (int x=(px-padRegion); x<=(px+padRegion); x++)
    {
        for (int y=(py-padRegion); y<=(py+padRegion); y++)
        {
            double rho = (*this->pRhoImage)(x,y);
            if ( ( rho > rhoEndo ) && ( rho < rhoEpi ) )
            {
                (*this->pMaskIschemic)(x,y) = (*pVolume)(x,y);
                listMyo.push_back((*pVolume)(x,y));
            }
        }
    }


    Otsu *filter = new Otsu();
    filter->SetInput(listMyo);
    filter->Update();
    this->ThreshIschemic = filter->GetOutputValue();
    cout << "Optimal threshold = " << this->ThreshIschemic << endl;

    for (int x=(px-padRegion); x<=(px+padRegion); x++)
    {
        for (int y=(py-padRegion); y<=(py+padRegion); y++)
        {
            if ( (*this->pMaskIschemic)(x,y) > this->ThreshIschemic ) {
                (*this->pMaskIschemic)(x,y) = 255;
            }
        }
    }
    */

/*
    /// Compute the actual segmentation mask
    double *sectorialMean = new double[ColsTheta];
    int *sectorialNb = new int[ColsTheta];
    for (int i=0; i<ColsTheta; i++) {
        sectorialMean[i] = 0.;
        sectorialNb[i] = 0;
    }
    for (int x=(px-padRegion); x<=(px+padRegion); x++)
    {
        for (int y=(py-padRegion); y<=(py+padRegion); y++)
        {
            double rho = (*this->pRhoImage)(x,y);
            if ( ( rho > rhoEndo ) && ( rho < rhoHalf ) )
            {
                int k = (*this->pThetaImage)(x,y);
                sectorialMean[k] += (*this->pVolume)(x,y);
                sectorialNb[k]++;
                (*this->pMaskIschemic)(x,y) = 128;
            }
        }
    }


    for (int k=0; k<16; k++)
    {
        double val = 0.;
        int nb = 0;
        for (int u=0; u<4; u++)
        {
            val += sectorialMean[k*4+u];
            nb += sectorialNb[k*4+u];
        }
        val = val / (nb+1e-12);
        for (int u=0; u<4; u++)
            sectorialMean[k*4+u] = val;
    }

    for (int x=(px-padRegion); x<=(px+padRegion); x++)
    {
        for (int y=(py-padRegion); y<=(py+padRegion); y++)
        {
            if ( (*this->pMaskIschemic)(x,y) == 128 )
            {
                int k = (*this->pThetaImage)(x,y);
                (*this->pMaskIschemic)(x,y) = sectorialMean[k];
            }
        }
    }
    */


    /*
    double spacing[3];
    this->pVolume->GetSpacing(spacing);
    double origin[3];
    this->pVolume->GetOrigin(origin);
    this->pRhoImage->Write(spacing,origin,"../../Results/RhoImage.mhd");
    this->pThetaImage->Write(spacing,origin,"../../Results/ThetaImage.mhd");
    this->pMaskIschemic->Write(spacing,origin,"../../Results/MaskIschemic.mhd");
    */

}


void Local2PhasesBEAS2DPolarCoupled::ComputeFeatureImage()
{
    //ComputeFeatureImageLocalChanVese();
    //ComputeFeatureImageSandro();
    //ComputeFeatureImageSandroBis();
    ComputeFeatureImageFIMH();
    //this->ComputeFeatureImageFIMHIschemic();
}

/// Made by Daniel -> round instead of floor + mean convolution
void Local2PhasesBEAS2DPolarCoupled::ComputeFeatureImageLocalChanVese()
{
    ComputeNormalMeshAndCurvature();

    /// Compute feature image
    double meanIn;
    double meanOut;
    double I;

    for (int j=0; j<ColsTheta; j++) {

        ///Endo
        meanIn = 0;
        meanOut = 0;
        for (int k=0; k<LocalDepth; k++)
        {
            meanIn += (*pVolume)(   (int)(std::floor( pSurfInfoEndo[j].surfX-StepDepthIn*k*pSurfInfoEndo[j].surfNormalX + 0.5)),
                                    (int)(std::floor( pSurfInfoEndo[j].surfY-StepDepthIn*k*pSurfInfoEndo[j].surfNormalY + 0.5)));
            meanOut += (*pVolume)(   (int)(std::floor( pSurfInfoEndo[j].surfX+StepDepthOut*k*pSurfInfoEndo[j].surfNormalX + 0.5)),
                                     (int)(std::floor( pSurfInfoEndo[j].surfY+StepDepthOut*k*pSurfInfoEndo[j].surfNormalY + 0.5)));
        }

        meanIn /= LocalDepth;
        meanOut /= LocalDepth;

        /// Compute final feature value
        I = (*pVolume)((int)(std::floor(pSurfInfoEndo[j].surfX+ 0.5)),
                       (int)(std::floor(pSurfInfoEndo[j].surfY+ 0.5)));
        (*pFeatureEndo)(0,j) = contrastSignEndo*(StepEndo*(I-meanIn)+(I-meanOut));

        ///Epi
        meanIn = 0;
        meanOut = 0;
        for (int k=0; k<LocalDepth; k++)
        {
            meanIn += (*pVolume)(   (int)(std::floor( pSurfInfoEpi[j].surfX-StepDepthIn*k*pSurfInfoEpi[j].surfNormalX + 0.5)),
                                    (int)(std::floor( pSurfInfoEpi[j].surfY-StepDepthIn*k*pSurfInfoEpi[j].surfNormalY + 0.5)));
            meanOut += (*pVolume)(  (int)(std::floor( pSurfInfoEpi[j].surfX+StepDepthOut*k*pSurfInfoEpi[j].surfNormalX + 0.5)),
                                    (int)(std::floor( pSurfInfoEpi[j].surfY+StepDepthOut*k*pSurfInfoEpi[j].surfNormalY + 0.5)));
        }

        meanIn /= LocalDepth;
        meanOut /= LocalDepth;

        /// Compute final feature value
        I = (*pVolume)((int)(std::floor(pSurfInfoEpi[j].surfX+ 0.5)),
                       (int)(std::floor(pSurfInfoEpi[j].surfY+ 0.5)));
        //(*pFeatureEpi)(0,j) = contrastSignEpi*(StepEndo*(I-meanIn)+(I-meanOut));  /// Added by Daniel
        (*pFeatureEpi)(0,j) = - ( (I-meanIn)*(I-meanIn) - 0.3*(I-meanOut)*(I-meanOut));

    }

    /// Normalize the pFeature values
    double maxFeatureEndo=0;
    double maxFeatureEpi=0;

    for (int j=0; j<ColsTheta; j++) {

        if (std::abs((*pFeatureEndo)(0,j)) > maxFeatureEndo)
            maxFeatureEndo = std::abs((*pFeatureEndo)(0,j));
        if (std::abs((*pFeatureEpi)(0,j)) > maxFeatureEpi)
            maxFeatureEpi = std::abs((*pFeatureEpi)(0,j));
    }

    for (int j=0; j<ColsTheta; j++) {
        (*pFeatureEndo)(0,j) = (*pFeatureEndo)(0,j) / maxFeatureEndo;
        (*pFeatureEpi)(0,j) = (*pFeatureEpi)(0,j) / maxFeatureEpi;

    }

}


/// Made by Olivier and inspired by Sandro's work
void Local2PhasesBEAS2DPolarCoupled::ComputeFeatureImageSandro()
{
    ComputeNormalMeshAndCurvature();

    /// Compute feature image
    double meanIn;
    double meanOut;
    double meanMyo;
    double I;

    for (int j=0; j<ColsTheta; j++) {

        ///Endo
        meanIn = 0.;
        meanMyo = 0.;
        for (int k=0; k<LocalDepth; k++)
        {
            meanIn += (*pVolume)(   (int)(std::floor( pSurfInfoEndo[j].surfX-StepDepthIn*k*pSurfInfoEndo[j].surfNormalX + 0.5)),
                                    (int)(std::floor( pSurfInfoEndo[j].surfY-StepDepthIn*k*pSurfInfoEndo[j].surfNormalY + 0.5)));
            meanMyo += (*pVolume)(  (int)(std::floor( pSurfInfoEndo[j].surfX+StepDepthOut*k*pSurfInfoEndo[j].surfNormalX + 0.5)),
                                    (int)(std::floor( pSurfInfoEndo[j].surfY+StepDepthOut*k*pSurfInfoEndo[j].surfNormalY + 0.5)));
        }
        meanIn /= LocalDepth;
        meanMyo /= LocalDepth;

        /// Compute final feature value for Endo
        I = (*pVolume)((int)(std::floor(pSurfInfoEndo[j].surfX + 0.5)),
                       (int)(std::floor(pSurfInfoEndo[j].surfY + 0.5)));
        (*pFeatureEndo)(0,j) = - ( (1+this->StepEndo)*I - this->StepEndo*meanIn - meanMyo );

        ///Epi
        meanMyo = 0.;
        meanOut = 0.;
        for (int k=0; k<LocalDepth; k++)
        {
            meanMyo += (*pVolume)(  (int)(std::floor( pSurfInfoEpi[j].surfX-StepDepthIn*k*pSurfInfoEpi[j].surfNormalX + 0.5)),
                                    (int)(std::floor( pSurfInfoEpi[j].surfY-StepDepthIn*k*pSurfInfoEpi[j].surfNormalY + 0.5)));
            meanOut += (*pVolume)(  (int)(std::floor( pSurfInfoEpi[j].surfX+StepDepthOut*k*pSurfInfoEpi[j].surfNormalX + 0.5)),
                                    (int)(std::floor( pSurfInfoEpi[j].surfY+StepDepthOut*k*pSurfInfoEpi[j].surfNormalY + 0.5)));
        }
        meanOut /= LocalDepth;
        meanMyo /= LocalDepth;

        /// Compute final feature value for Epi
        I = (*pVolume)((int)(std::floor(pSurfInfoEpi[j].surfX + 0.5)),
                       (int)(std::floor(pSurfInfoEpi[j].surfY + 0.5)));
        (*pFeatureEpi)(0,j) = -( (I-meanMyo)*(I-meanMyo) - this->StepEpi*(I-meanOut)*(I-meanOut) );
    }

    /// Normalize the pFeature values
    double maxFeatureEndo=0;
    double maxFeatureEpi=0;

    for (int j=0; j<ColsTheta; j++) {

        if (std::abs((*pFeatureEndo)(0,j)) > maxFeatureEndo)
            maxFeatureEndo = std::abs((*pFeatureEndo)(0,j));
        if (std::abs((*pFeatureEpi)(0,j)) > maxFeatureEpi)
            maxFeatureEpi = std::abs((*pFeatureEpi)(0,j));
    }

    for (int j=0; j<ColsTheta; j++) {
        (*pFeatureEndo)(0,j) = -contrastSignEndo*(*pFeatureEndo)(0,j) / maxFeatureEndo;
        (*pFeatureEpi)(0,j) = (*pFeatureEpi)(0,j) / maxFeatureEpi;

    }

}


/// Made by Olivier and inspired by Sandro's work
void Local2PhasesBEAS2DPolarCoupled::ComputeFeatureImageSandroBis()
{

    /// Compute feature image
    double I;

    //vtkTimerLog *timer = vtkTimerLog::New();
    //timer->StartTimer();
    /// Compute the actual segmentation mask
    int size[3];
    this->pVolume->GetDimensions(size);
    DoubleImageAccess *pMaskEndo = new DoubleImageAccess(size[0],size[1],0);
    DoubleImageAccess *pMaskEpi = new DoubleImageAccess(size[0],size[1],0);
    DoubleImageAccess *pMaskMyo = new DoubleImageAccess(size[0],size[1],0);
    for (int x=0; x<size[0]; x++)
    {
        for (int y=0; y<size[1]; y++)
        {
            int k = (*this->pThetaImage)(x,y);
            if ( (*this->pRhoImage)(x,y) < (*this->pMeshEndo)(0,k) )
                (*pMaskEndo)(x,y) = 255;
            if ( (*this->pRhoImage)(x,y) > (*this->pMeshEpi)(0,k) )
                (*pMaskEpi)(x,y) = 255;
            if ( ( (*this->pRhoImage)(x,y) > (*this->pMeshEndo)(0,k) ) &&
                 ( (*this->pRhoImage)(x,y) < (*this->pMeshEpi)(0,k) ) )
                (*pMaskMyo)(x,y) = 255;
        }
    }
    /*
    string filenameEndo = "../../Results/pMaskEndo.mhd";
    pMaskEndo->Write(spacing,offset,filenameEndo.c_str());
    string filenameEpi = "../../Results/pMaskEpi.mhd";
    pMaskEpi->Write(spacing,offset,filenameEpi.c_str());
    string filenameMyo = "../../Results/pMaskMyo.mhd";
    pMaskMyo->Write(spacing,offset,filenameMyo.c_str());
    */
    //timer->StopTimer();
    //std::cout << ">> elapsed time for vessel segmentation = " << timer->GetElapsedTime() << " seconds" << std::endl;    // Display result

    for (int j=0; j<ColsTheta; j++)
    {

        /// Make Epi feature
        int px = (int)(std::floor(pSurfInfoEpi[j].surfX+0.5));
        int py = (int)(std::floor(pSurfInfoEpi[j].surfY+0.5));
        double epiIn = 0.;
        int epiInNb = 0;
        double epiOut = 0.;
        int epiOutNb = 0;
        for (int u=(px-LocalDepth); u<=(px+LocalDepth); u++) {
            for (int v=(py-LocalDepth); v<=(py+LocalDepth); v++) {
                if ( (*pMaskMyo)(u,v) > 0 ) {
                    epiInNb++;
                    epiIn += (*this->pVolume)(u,v);
                }
                if ( (*pMaskEpi)(u,v) > 0 ) {
                    epiOutNb++;
                    epiOut += (*this->pVolume)(u,v);
                }
            }
        }
        epiIn /= epiInNb;
        epiOut /= epiOutNb;
        I = (*pVolume)(px,py);
        (*pFeatureEpi)(0,j) = -( (I-epiIn)*(I-epiIn) - this->StepEpi*(I-epiOut)*(I-epiOut) );

        /// Make Endo feature
        px = (int)(std::floor(pSurfInfoEndo[j].surfX+0.5));
        py = (int)(std::floor(pSurfInfoEndo[j].surfY+0.5));
        double endoIn = 0.;
        int endoInNb = 0;
        double endoOut = 0.;
        int endoOutNb = 0;
        for (int u=(px-LocalDepth); u<=(px+LocalDepth); u++) {
            for (int v=(py-LocalDepth); v<=(py+LocalDepth); v++) {
                if ( (*pMaskMyo)(u,v) > 0 ) {
                    endoOutNb++;
                    endoOut += (*this->pVolume)(u,v);
                }
                if ( (*pMaskEndo)(u,v) > 0 ) {
                    endoInNb++;
                    endoIn += (*this->pVolume)(u,v);
                }
            }
        }
        endoIn /= endoInNb;
        endoOut /= endoOutNb;
        I = (*pVolume)(px,py);
        (*pFeatureEndo)(0,j) = - ( (1+this->StepEndo)*I - this->StepEndo*endoIn - endoOut );

    }

    /// Normalize the pFeature values
    double maxFeatureEndo=0;
    double maxFeatureEpi=0;

    for (int j=0; j<ColsTheta; j++) {

        if (std::abs((*pFeatureEndo)(0,j)) > maxFeatureEndo)
            maxFeatureEndo = std::abs((*pFeatureEndo)(0,j));
        if (std::abs((*pFeatureEpi)(0,j)) > maxFeatureEpi)
            maxFeatureEpi = std::abs((*pFeatureEpi)(0,j));
    }

    for (int j=0; j<ColsTheta; j++) {
        (*pFeatureEndo)(0,j) = -contrastSignEndo*(*pFeatureEndo)(0,j) / maxFeatureEndo;
        (*pFeatureEpi)(0,j) = (*pFeatureEpi)(0,j) / maxFeatureEpi;

    }

}


/// Made by Olivier and inspired by Sandro's work
void Local2PhasesBEAS2DPolarCoupled::ComputeFeatureImageFIMH()
{

    /// Compute feature image
    double I;
    this->MyoMean = 0.;
    int myoNb = 0;

    /// Compute the region of interest to optimally create the different masks
    double maxEpi = 0.;
    for (int k=0; k<ColsTheta; k++)
    {
        if ( maxEpi < (*this->pMeshEpi)(0,k) )
            maxEpi = (*this->pMeshEpi)(0,k);
    }
    int padRegion = (int)(maxEpi) + 3;
    int px = (int)(this->GetCenterPointX());
    int py = (int)(this->GetCenterPointY());

    /// Compute the actual segmentation mask
    int size[3];
    this->pVolume->GetDimensions(size);
    DoubleImageAccess *pMaskMyo = new DoubleImageAccess(size[0],size[1],0);
    for (int x=(px-padRegion); x<=(px+padRegion); x++)
    {
        for (int y=(py-padRegion); y<=(py+padRegion); y++)
        {
            int k = (*this->pThetaImage)(x,y);
            if ( ((*this->pRhoImage)(x,y) > (*this->pMeshEndo)(0,k)) &&
                 ((*this->pRhoImage)(x,y) < (*this->pMeshEpi)(0,k)) )
            {
                (*pMaskMyo)(x,y) = 255;
                myoNb++;
                this->MyoMean+=(*this->pVolume)(x,y);
            }
        }
    }
    this->MyoMean /= (myoNb+1e-12);

    for (int j=0; j<ColsTheta; j++)
    {

        /// Make Epi feature
        int px = (int)(std::floor(pSurfInfoEpi[j].surfX+0.5));
        int py = (int)(std::floor(pSurfInfoEpi[j].surfY+0.5));
        double epiIn = 0.;
        int epiInNb = 0;
        double epiOut = 0.;
        int epiOutNb = 0;
        for (int u=(px-LocalDepth); u<=(px+LocalDepth); u++) {
            for (int v=(py-LocalDepth); v<=(py+LocalDepth); v++) {
                if ( (*pMaskMyo)(u,v) > 0 ) {
                    epiInNb++;
                    epiIn += (*this->pVolume)(u,v);
                }
                else {
                    epiOutNb++;
                    epiOut += (*this->pVolume)(u,v);
                }
            }
        }
        epiIn /= (epiInNb+1e-12);
        epiOut /= (epiOutNb+1e-12);
        I = (*pVolume)(px,py);
        (*pFeatureEpi)(0,j) = -( (I-(epiIn+this->MyoMean)/2)*(I-(epiIn+this->MyoMean)/2) -
                                 this->StepEpi*(I-epiOut)*(I-epiOut) );

        /// Make Endo feature
        px = (int)(std::floor(pSurfInfoEndo[j].surfX+0.5));
        py = (int)(std::floor(pSurfInfoEndo[j].surfY+0.5));
        double endoIn = 0.;
        int endoInNb = 0;
        double endoOut = 0.;
        int endoOutNb = 0;
        for (int u=(px-LocalDepth); u<=(px+LocalDepth); u++) {
            for (int v=(py-LocalDepth); v<=(py+LocalDepth); v++) {
                if ( (*pMaskMyo)(u,v) > 0 ) {
                    endoOutNb++;
                    endoOut += (*this->pVolume)(u,v);
                }
                else {
                    endoInNb++;
                    endoIn += (*this->pVolume)(u,v);
                }
            }
        }
        endoIn /= (endoInNb+1e-12);
        endoOut /= (endoOutNb+1e-12);
        I = (*pVolume)(px,py);
        (*pFeatureEndo)(0,j) = - ( this->StepEndo*(I-endoIn)*(I-endoIn) -
                                 (I-(endoOut+this->MyoMean)/2)*(I-(endoOut+this->MyoMean)/2) );

    }

    /// Normalize the pFeature values
    double maxFeatureEndo = 0;
    double maxFeatureEpi = 0;

    for (int j=0; j<ColsTheta; j++) {

        if (std::abs((*pFeatureEndo)(0,j)) > maxFeatureEndo)
            maxFeatureEndo = std::abs((*pFeatureEndo)(0,j));
        if (std::abs((*pFeatureEpi)(0,j)) > maxFeatureEpi)
            maxFeatureEpi = std::abs((*pFeatureEpi)(0,j));
    }

    for (int j=0; j<ColsTheta; j++) {
        (*pFeatureEndo)(0,j) = (*pFeatureEndo)(0,j) / maxFeatureEndo;
        (*pFeatureEpi)(0,j)  = (*pFeatureEpi)(0,j) / maxFeatureEpi;

    }

}


/*
/// Made by Olivier and inspired by Sandro's work
void Local2PhasesBEAS2DPolarCoupled::ComputeFeatureImageFIMHIschemic()
{

    /// Compute feature image
    double I;
    this->MyoMean = 0.;
    int myoNb = 0;

    /// Compute the region of interest to optimally create the different masks
    double maxEpi = 0.;
    for (int k=0; k<ColsTheta; k++)
    {
        if ( maxEpi < (*this->pMeshEpi)(0,k) )
            maxEpi = (*this->pMeshEpi)(0,k);
    }
    int padRegion = (int)(maxEpi) + 3;
    int px = (int)(this->GetCenterPointX());
    int py = (int)(this->GetCenterPointY());

    /// Compute the actual segmentation mask
    int size[3];
    this->pVolume->GetDimensions(size);
    DoubleImageAccess *pMaskMyo = new DoubleImageAccess(size[0],size[1],0);
    vector<double> listMyo;
    for (int x=(px-padRegion); x<=(px+padRegion); x++)
    {
        for (int y=(py-padRegion); y<=(py+padRegion); y++)
        {
            int k = (*this->pThetaImage)(x,y);
            if ( ((*this->pRhoImage)(x,y) > (*this->pMeshEndo)(0,k)) &&
                 ((*this->pRhoImage)(x,y) < (*this->pMeshEpi)(0,k)) )
            {
                listMyo.push_back((*pVolume)(x,y));
                (*pMaskMyo)(x,y) = 255;
                //myoNb++;
                //this->MyoMean+=(*this->pVolume)(x,y);
            }
        }
    }
    //this->MyoMean /= (myoNb+1e-12);

    Otsu *filter = new Otsu();
    filter->SetInput(listMyo);
    filter->Update();
    this->ThreshIschemic = filter->GetOutputValue();
    cout << "Optimal threshold = " << this->ThreshIschemic << endl;

    for (int x=(px-padRegion); x<=(px+padRegion); x++)
    {
        for (int y=(py-padRegion); y<=(py+padRegion); y++)
        {
            if ( ((*pMaskMyo)(x,y)==255) &&
                 ((*pVolume)(x,y)<this->ThreshIschemic) ) {
                myoNb++;
                this->MyoMean+=(*this->pVolume)(x,y);
            }
        }
    }
    if ( myoNb > 0 )
        this->MyoMean /= myoNb;

    for (int j=0; j<ColsTheta; j++)
    {

        /// Make Epi feature
        int px = (int)(std::floor(pSurfInfoEpi[j].surfX+0.5));
        int py = (int)(std::floor(pSurfInfoEpi[j].surfY+0.5));

        double epiIn = 0.;
        int epiInNb = 0;
        double epiOut = 0.;
        int epiOutNb = 0;
        for (int u=(px-LocalDepth); u<=(px+LocalDepth); u++) {
            for (int v=(py-LocalDepth); v<=(py+LocalDepth); v++) {
                if ( (*pMaskMyo)(u,v) > 0 ) {
                    epiInNb++;
                    epiIn += (*this->pVolume)(u,v);
                }
                else {
                    epiOutNb++;
                    epiOut += (*this->pVolume)(u,v);
                }
            }
        }
        epiIn /= (epiInNb+1e-12);
        epiOut /= (epiOutNb+1e-12);
        I = (*pVolume)(px,py);
        (*pFeatureEpi)(0,j) = -( (I-(epiIn+this->MyoMean)/2)*(I-(epiIn+this->MyoMean)/2) -
                                 this->StepEpi*(I-epiOut)*(I-epiOut) );

        /// Make Endo feature
        px = (int)(std::floor(pSurfInfoEndo[j].surfX+0.5));
        py = (int)(std::floor(pSurfInfoEndo[j].surfY+0.5));

        double endoIn = 0.;
        int endoInNb = 0;
        double endoOut = 0.;
        int endoOutNb = 0;
        for (int u=(px-LocalDepth); u<=(px+LocalDepth); u++) {
            for (int v=(py-LocalDepth); v<=(py+LocalDepth); v++) {
                if ( (*pMaskMyo)(u,v) > 0 ) {
                    endoOutNb++;
                    endoOut += (*this->pVolume)(u,v);
                }
                else {
                    endoInNb++;
                    endoIn += (*this->pVolume)(u,v);
                }
            }
        }
        endoIn /= (endoInNb+1e-12);
        endoOut /= (endoOutNb+1e-12);
        I = (*pVolume)(px,py);
        (*pFeatureEndo)(0,j) = - ( this->StepEndo*(I-endoIn)*(I-endoIn) -
                                 (I-(endoOut+this->MyoMean)/2)*(I-(endoOut+this->MyoMean)/2) );

    }

    /// Normalize the pFeature values
    double maxFeatureEndo = 0;
    double maxFeatureEpi = 0;

    for (int j=0; j<ColsTheta; j++) {

        if (std::abs((*pFeatureEndo)(0,j)) > maxFeatureEndo)
            maxFeatureEndo = std::abs((*pFeatureEndo)(0,j));
        if (std::abs((*pFeatureEpi)(0,j)) > maxFeatureEpi)
            maxFeatureEpi = std::abs((*pFeatureEpi)(0,j));
    }

    for (int j=0; j<ColsTheta; j++) {
        (*pFeatureEndo)(0,j) = (*pFeatureEndo)(0,j) / maxFeatureEndo;
        (*pFeatureEpi)(0,j)  = (*pFeatureEpi)(0,j) / maxFeatureEpi;

    }

}
*/

