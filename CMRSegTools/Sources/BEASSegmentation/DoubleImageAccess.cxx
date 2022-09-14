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

#include "DoubleImageAccess.h"

#include <iostream>

using namespace std;

 DoubleImageAccess::DoubleImageAccess() :
    DataSize(0), Rows(0), Cols(0), pData(NULL) {}


 DoubleImageAccess::DoubleImageAccess(int rows, int cols) :
    DataSize(0), Rows(0), Cols(0), pData(NULL)
{
    alloc(rows, cols);
}

 DoubleImageAccess::DoubleImageAccess(int rows, int cols, double val) :
    DataSize(0), Rows(0), Cols(0), pData(NULL)
{
    alloc(rows, cols);
    for (int i = 0; i<DataSize; i++)
        pData[i] = val;
}

 DoubleImageAccess::DoubleImageAccess(const DoubleImageAccess &m) :
    DataSize(0), Rows(0), Cols(0), pData(0)
{
  alloc(m.Rows, m.Cols);
  copy_vector<double>(m.DataSize, m.pData, pData);
}

 DoubleImageAccess::~DoubleImageAccess()
{
  free();
}

void DoubleImageAccess::alloc(int rows, int cols)
{
    if ((rows > 0) && (cols > 0))
    {
        DataSize = rows * cols;
        Rows = rows;
        Cols = cols;
        create_elements(pData, DataSize);
    }
}


void DoubleImageAccess::DeepCopy(DoubleImageAccess m)
{
    alloc(m.Rows, m.Cols);
    copy_vector<double>(m.DataSize, m.pData, pData);
}


//! Specialization for 16-byte aligned double data arrays
 void DoubleImageAccess::create_elements(double* &ptr, int n)
{
  void *p0 = operator new(sizeof(double) * n + 16);
  void *p1 = reinterpret_cast<void*>((reinterpret_cast<std::size_t>(p0) + 16)
                                     & (~(std::size_t(15))));
  *(reinterpret_cast<void**>(p1) - 1) = p0;
  ptr = reinterpret_cast<double*>(p1);
}


 void DoubleImageAccess::free()
{
  destroy_elements(pData);
  DataSize = 0;
  Rows = 0;
  Cols = 0;
}


//! Specialisation for 16-byte aligned double data arrays
 void DoubleImageAccess::destroy_elements(double* &ptr)
{
  if (ptr) {
    void *p = *(reinterpret_cast<void**>(ptr) - 1);
    operator delete(p);
    ptr = 0;
  }
}


 DoubleImageAccess& DoubleImageAccess::operator=(double t)
{
  for (int i=0; i<DataSize; i++)
    pData[i] = t;
  return *this;
}

 DoubleImageAccess& DoubleImageAccess::operator=(const DoubleImageAccess &m)
{
  if (this != &m) {
    set_size(m.Rows, m.Cols, false);
    if (m.DataSize != 0)
      copy_vector<double>(m.DataSize, m.pData, pData);
  }
  return *this;
}

 DoubleImageAccess DoubleImageAccess::operator+(const DoubleImageAccess &m)
{
  DoubleImageAccess r(m.Rows, m.Cols);
  int i, j, m_pos = 0, pos = 0, r_pos = 0;

  for (i=0; i<r.Cols; i++) {
    for (j=0; j<r.Rows; j++)
      r.pData[r_pos+j] = pData[pos+j] + m.pData[m_pos+j];
    // next column
    m_pos += m.Rows;
    pos += Rows;
    r_pos += r.Rows;
  }

  return r;
}

 DoubleImageAccess& DoubleImageAccess::operator+=(const DoubleImageAccess &m)
{
  if (DataSize == 0)
    operator=(m);
  else {
    int i, j, m_pos = 0, pos = 0;
    for (i=0; i<Cols; i++) {
      for (j=0; j<Rows; j++)
        pData[pos+j] += m.pData[m_pos+j];
      pos += Rows;
      m_pos += m.Rows;
    }
  }
  return *this;
}

 DoubleImageAccess& DoubleImageAccess::operator+=(double t)
{
  for (int i=0; i<DataSize; i++)
    pData[i] += t;
  return *this;
}

 DoubleImageAccess DoubleImageAccess::operator*(double t)
{
    DoubleImageAccess r(Rows, Cols);

    for (int i=0; i<r.DataSize; i++)
        r.pData[i] = pData[i] * t;

    return r;
}


void DoubleImageAccess::set_size(int rows, int cols, bool copy)
{
  // check if we have to resize the current matrix
  if ((Rows == rows) && (Cols == cols))
    return;
  // check if one of dimensions is zero
  if ((rows == 0) || (cols == 0)) {
    free();
    return;
  }
  // conditionally copy previous matrix content
  if (copy) {
    // create a temporary pointer to the allocated data
    double* tmp = pData;
    // store the current number of elements and number of rows
    //int old_datasize = DataSize;
    int old_rows = Rows;
    // check the boundaries of the copied data
    int min_r = (Rows < rows) ? Rows : rows;
    int min_c = (Cols < cols) ? Cols : cols;
    // allocate new memory
    alloc(rows, cols);
    // copy the previous data into the allocated memory
    for (int i = 0; i < min_c; ++i) {
      copy_vector<double>(min_r, &tmp[i*old_rows], &pData[i*Rows]);
    }
    // fill-in the rest of matrix with zeros
    for (int i = min_r; i < rows; ++i)
      for (int j = 0; j < cols; ++j)
        pData[i+j*rows] = double(0);
    for (int j = min_c; j < cols; ++j)
      for (int i = 0; i < min_r; ++i)
        pData[i+j*rows] = double(0);
    // delete old elements
    destroy_elements(tmp);
  }
  // if possible, reuse the allocated memory
  else if (DataSize == rows * cols) {
    Rows = rows;
    Cols = cols;
  }
  // finally release old memory and allocate a new one
  else {
    free();
    alloc(rows, cols);
  }
}

void DoubleImageAccess::PrintImageInfo( )
{
    cout << "image = " << pData << endl;
    cout << "size image = <" << Rows << "," << Cols << ">" << endl;
    cout << "--------------------------------------" << endl;
}


