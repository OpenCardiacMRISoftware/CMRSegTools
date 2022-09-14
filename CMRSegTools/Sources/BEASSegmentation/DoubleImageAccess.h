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
*/

#ifndef _DoubleImageAccess_h_
#define _DoubleImageAccess_h_

#include <iostream>
#include <cstring>

using namespace std;


class DoubleImageAccess
{

    private:

        int DataSize;
        int Rows;
        int Cols;
        double *pData;

        void alloc(int rows, int cols);
        void create_elements(double* &ptr, int n);
        void destroy_elements(double* &ptr);
        void free();

        template<class T>
        void copy_vector(const int n, const T *x, T *y) {
            memcpy(y, x, (unsigned int)n*sizeof(T)); }


    public:

        explicit DoubleImageAccess();
        DoubleImageAccess(int rows, int cols);
        DoubleImageAccess(int rows, int cols, double val);
        DoubleImageAccess(const DoubleImageAccess &m);
        virtual ~DoubleImageAccess();

        void DeepCopy(DoubleImageAccess m);

        DoubleImageAccess& operator=(double t);
        DoubleImageAccess& operator=(const DoubleImageAccess &m);
        DoubleImageAccess& operator+=(const DoubleImageAccess &m);
        DoubleImageAccess& operator+=(double t);
        DoubleImageAccess operator+(const DoubleImageAccess &m);
        DoubleImageAccess operator*(double t);

        //! Set size of matrix. If copy = true then keep the data before resizing.
        void set_size(int rows, int cols, bool copy = false);

        double* get_row_( int r ) const {
            return pData + r;
        }
        double* get_col_( int c ) const {
            return pData + c*Rows;
        }
        const double &operator()(int r, int c) const {
            return pData[r+c*Rows];
        }
        double &operator()(int r, int c) {
            return pData[r+c*Rows];
        }
        const double &operator()(int k) const {
            return pData[k];
        }
        double &operator()(int k) {
            return pData[k];
        }

        void PrintImageInfo();

        int GetRows() const {
            return Rows;
        }

        int GetCols() const {
            return Cols;
        }

};

#endif

