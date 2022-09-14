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
*/

#ifndef _PointAccess_h_
#define _PointAccess_h_

#include <iostream>

using namespace std;


class PointAccess
{

    private:
        double X;
        double Y;
        double Z;

    public:
        PointAccess() : X(0), Y(0), Z(0) {};
        PointAccess(double a, double b, double c) : X(a), Y(b), Z(c) {};
        PointAccess( const PointAccess &a ) { X = a.X; Y = a.Y; Z = a.Z; }
        double GetX() const { return X; }
        double GetY() const { return Y; }
        double GetZ() const { return Z; }
        void SetPoint( const PointAccess &a ) { X = a.X; Y = a.Y; Z = a.Z; }
        void SetPoint( double a, double b, double c ) { X = a; Y = b; Z = c; }
        void Print() const { cout << "point coordinates = (" << X << "," << Y << "," << Z << ")" << endl; }

};


#endif

