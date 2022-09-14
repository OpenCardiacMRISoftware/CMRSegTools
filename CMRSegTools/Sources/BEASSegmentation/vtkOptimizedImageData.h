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

#ifndef __vtkOptimizedImageData_h__
#define __vtkOptimizedImageData_h__

#include <vtkObjectFactory.h>
#include <vtkImageData.h>
#include <vtkPointData.h>
#include <vtkDataArray.h>


using namespace std;

template<class T>
class VTK_EXPORT vtkOptimizedImageData : public vtkImageData
{

    private:

        T* data;
        int dimX;
        int dimY;
        int dimZ;

    protected:

        vtkOptimizedImageData() : data(NULL) {}
        ~vtkOptimizedImageData() {}

    public:

        static vtkOptimizedImageData *New()
        {
            vtkObject* ret = vtkObjectFactory::CreateInstance("vtkOptimizedImageData");
            if(ret) { return (vtkOptimizedImageData*)ret; }
            // If the factory was unable to create the object, then create it here.
            return (new vtkOptimizedImageData);
        }

        vtkOptimizedImageData& operator=(vtkImageData &m)
        {
            this->DeepCopy(&m);
            return *this;
        }

        T& operator()(int x, int y, int z)
        {
            if ( !data ) {
                data = static_cast<T*>(this->PointData->GetScalars()->GetVoidPointer(0));
                dimX = this->GetDimensions()[0];
                dimY = this->GetDimensions()[1];
                dimZ = this->GetDimensions()[2];
            }
            if ( (x>=0 && x<dimX) && (y>=0 && y<dimY) && (z>=0 && z<dimZ) )
                return data[x+y*dimX+z*dimX*dimY];
            else
            {
                cout << "Take care, try to access a point out of the volume" << endl;
                return data[0];
            }
        }

        T& operator()(int x, int y)
        {
            if ( !data ) {
                data = static_cast<T*>(this->PointData->GetScalars()->GetVoidPointer(0));
                dimX = this->GetDimensions()[0];
                dimY = this->GetDimensions()[1];
                dimZ = 1;
            }
            if ( (x>=0 && x<dimX) && (y>=0 && y<dimY) )
                return data[x+y*dimX];
            else
            {
                cout << "Take care, try to access a point out of the volume" << endl;
                return data[0];
            }
        }

        T& operator()(int k)
        {
            if ( !data ) {
                data = static_cast<T*>(this->PointData->GetScalars()->GetVoidPointer(0));
                dimX = this->GetDimensions()[0];
                dimY = this->GetDimensions()[1];
                dimZ = this->GetDimensions()[2];
            }
            if (k>=0 && k<dimX*dimY*dimZ)
                return data[k];
            else
            {
                cout << "Take care, try to access a point out of the volume" << endl;
                return data[0];
            }
        }

        void PrintDataPointer()
        {
                cout << "data = " << this->PointData->GetScalars()->GetVoidPointer(0) << endl;
        }


        void Update()
        {
	        AllocateScalars();
            this->Superclass::Update();
        }

        void PrintInfo();

        /// Added by Daniel
        void CopyImage(vtkDataObject *src)
        {
            this->DeepCopy(src);
            data = static_cast<T*>(this->PointData->GetScalars()->GetVoidPointer(0));
            dimX = this->GetDimensions()[0];
            dimY = this->GetDimensions()[1];
            dimZ = this->GetDimensions()[2];
        }


};


#endif
