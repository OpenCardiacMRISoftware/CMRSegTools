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
* CREATIS-LRMN Laboratory,
* 69621 Villeurbanne, France,
* 11th of May 2011
* Updated 06th May 2013
*/

#ifndef _Local2PhasesBEAS2DPolarCoupled_h_
#define _Local2PhasesBEAS2DPolarCoupled_h_

#include "BEAS2DPolarCoupled.h"
#include "DoubleImageAccess.h"

using namespace std;


class Local2PhasesBEAS2DPolarCoupled : public BEAS2DPolarCoupled
{

    protected:

        void ComputeFeatureImage();
        void ComputeFeatureImageLocalChanVese();
        void ComputeFeatureImageSandro();
        void ComputeFeatureImageSandroBis();
        void ComputeFeatureImageFIMH();
        //void ComputeFeatureImageFIMHIschemic();
        void InitializeStructures();

        DoubleImageAccess *pThetaImage;
        DoubleImageAccess *pRhoImage;
        //DoubleImageAccess *pMaskIschemic;
        double MyoMean;
        double ThreshIschemic;

    public:

        Local2PhasesBEAS2DPolarCoupled();
        virtual ~Local2PhasesBEAS2DPolarCoupled();

        DoubleImageAccess* GetThetaImage() { return pThetaImage; }
        DoubleImageAccess* GetRhoImage() { return pRhoImage; }
        double GetMyocardiumMeanIntensity() { return MyoMean; }

};


#endif

