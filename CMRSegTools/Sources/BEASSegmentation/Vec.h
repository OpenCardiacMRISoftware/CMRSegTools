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

#ifndef _Vec_h_
#define _Vec_h_

#include <iostream>
#include <sstream>
#include <limits>
#include <cmath>
#include <vector>
#include <string.h>
#include <cstdio>


template<class Num_T>
class Vec
{
    public:

        /// Default constructor.
        Vec() : datasize(0), data(0) {}
        /// Constructor with size parameter.
        Vec(int size): datasize(0), data(0)
	{
	    alloc(size);
	}

        /// Copy constructor
        Vec(const Vec<Num_T> &v) : datasize(0), data(0)
	{
	    alloc(v.datasize);
	    copy_vector(datasize, v.data, data);
	}

        /// Constructor taking a char string as input.
        Vec(const char *values): datasize(0), data(0)
	{
	    set(values);
	}

        /// Constructor taking a string as input.
        Vec(const std::string &values) : datasize(0), data(0)
	{
	    set(values);
	}

        /// Constructor taking a C-array as input. Copies all data.
        Vec(const Num_T *c_array, int size) : datasize(0), data(0)
	{
	    alloc(size);
	    copy_vector(size, c_array, data);
	}

        /// Destructor
        ~Vec() { free(); }

        /// The size of the vector
        int length() const { return datasize; }
        /// The size of the vector
        int size() const { return datasize; }

        /// Set length of vector. if copy = true then keeping the old values
        void set_size(int size, bool copy = false)
	{
	    if (datasize == size)
		return;
	    if (copy)
	    {
		/// create a temporary pointer to the allocated data
		Num_T* tmp = data;
		/// check how many elements we need to copy
		int min = datasize < size ? datasize : size;
		/// allocate new memory
		alloc(size);
		/// copy old elements into a new memory region
		copy_vector(min, tmp, data);
		/// initialize the rest of resized vector
		for (int i = min; i < size; ++i)
		    data[i] = Num_T(0);
		/// delete old elements
		delete[] tmp;
	    }
	    else {
		free();
		alloc(size);
	    }
	}

        /// Set length of vector. if copy = true then keeping the old values
        void set_length(int size, bool copy = false) { set_size(size, copy); }

        /// Set the vector to the all zero vector
        void zeros()
	{
	    for (int i = 0; i < datasize; i++)
		data[i] = Num_T(0);
	}

        /// Set the vector to the all zero vector
        void clear() { zeros(); }

        /// Set the vector to the all one vector
        void ones()
	{
	    for (int i = 0; i < datasize; i++)
		data[i] = Num_T(1);
	}

        /// Set the vector equal to the values in the \c str string
        void set(const char *str)
	{
	    set(std::string(str));
	}

        /// Set the vector equal to the values in the \c str string
        void set(const std::string &str);

        /// Assign all elements in vector to t
        Vec<Num_T>& operator=(Num_T t)
	{
	    for (int i = 0; i < datasize; i++)
		data[i] = t;
	    return *this;
	}

        /// Assign vector the value and length of v
        Vec<Num_T>& operator=(const Vec<Num_T> &v)
	{
	    if (this != &v)
	    {
		set_size(v.datasize, false);
		copy_vector(datasize, v.data, data);
	    }
	    return *this;
	}

        /// Assign vector the values in the string values
        Vec<Num_T>& operator=(const char *values)
	{
	    set(values);
	    return *this;
	}

        /// C-style index operator. First element is 0
        const Num_T &operator[](int i) const
	{
	    return data[i];
	}

        /// Index operator. First element is 0
        const Num_T &operator()(int i) const
	{
	    return data[i];
	}

        /// C-style index operator. First element is 0
        Num_T &operator[](int i)
	{
	    return data[i];
	}

        /// Index operator. First element is 0
        Num_T &operator()(int i)
	{
	    return data[i];
	}

    protected:

        /// Allocate storage for a vector of length size
        void alloc(int size)
	{
	    if (size > 0)
	    {
		data = new Num_T[size];
		datasize = size;
	    }
	    else
	    {
		data = 0;
		datasize = 0;
	    }
	}

        /// Free the storage space allocated by the vector
        void free()
	{
	    if (data)
		delete[] data;
	    data = 0;
	    datasize = 0;
	}

        void copy_vector(const int n, const Num_T *x, Num_T *y) {
            memcpy(y, x, (unsigned int)n*sizeof(Num_T)); }

        /// The current number of elements in the vector
        int datasize;
        /// A pointer to the data area
        Num_T *data;

    private:

        /// This function is used in set() methods to replace commas with spaces
        std::string replace_commas(const std::string &str);

        /// Check whether index i is in the allowed range
        bool in_range(int i) const { return ((i < datasize) && (i >= 0)); }


};


/// Definition of double vector type
typedef Vec<double> vec;

/// Definition of integer vector type
typedef Vec<int> ivec;

/// Definition of short vector type
typedef Vec<short int> svec;

#endif

