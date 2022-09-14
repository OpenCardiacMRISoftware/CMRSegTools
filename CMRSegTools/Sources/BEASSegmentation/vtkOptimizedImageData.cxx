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
* Progam made by Olivier Bernard, associate professor
* at Institut National des Sciences Appliquees (INSA) Lyon,
* CREATIS-LRMN Laboratory,
* 69621 Villeurbanne, France,
* 31th of march 2011
*/

#include "vtkOptimizedImageData.h"

using namespace std;


template<class T>
void vtkOptimizedImageData<T>::PrintInfo()
{
    cout << "Image pointer: " << data << endl;
    cout << "Image dimension: [" << dimX << "," << dimY << "," << dimZ << "]" << endl;
}

