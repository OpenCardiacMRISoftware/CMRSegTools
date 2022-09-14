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

#include "Vec.h"

#include <iostream>
#include <sstream>
#include <limits>
#include <cmath>
#include <vector>
#include <cstdio>
#include <string.h>


template<>
void Vec<double>::set(const std::string &str)
{
    std::istringstream buffer(replace_commas(str));
    double b = 0.0;
    double c = 0.0;
    double eps_margin;
    bool b_parsed = false;
    bool c_parsed = false;
    bool negative = false;
    bool nan_inf = false;
    int pos = 0, maxpos = 10;

    free();
    alloc(maxpos);

    while (buffer.peek() != EOF)
    {
        switch (buffer.peek())
        {
            /// skip spaces
            case ' ':
            case '\t':
                buffer.seekg(1, std::ios_base::cur);
                break;

            /// skip '+' sign
            case '+':
                /// check for not handled '-' sign
                buffer.seekg(1, std::ios_base::cur);
                break;

            /// check for '-' sign
            case '-':
                buffer.seekg(1, std::ios_base::cur);
                negative = true;
                break;

            /// check for NaN
            case 'N':
            case 'n':
                buffer.seekg(1, std::ios_base::cur);
                buffer.seekg(1, std::ios_base::cur);
                buffer.seekg(1, std::ios_base::cur);
                if (++pos > maxpos) {
                    maxpos <<= 1;
                    set_size(maxpos, true);
                }
                if (std::numeric_limits<double>::has_quiet_NaN) {
                    data[pos-1] = std::numeric_limits<double>::quiet_NaN();
                }
                else if (std::numeric_limits<double>::has_signaling_NaN) {
                    data[pos-1] = std::numeric_limits<double>::signaling_NaN();
                }
                else {
                    std::cout << "Vec<double::set(): NaN not supported" << std::endl;
                }
                nan_inf = true;
                break; /// case 'N'...

            /// check for Inf
            case 'I':
            case 'i':
                buffer.seekg(1, std::ios_base::cur);
                buffer.seekg(1, std::ios_base::cur);
                buffer.seekg(1, std::ios_base::cur);
                if (++pos > maxpos) {
                    maxpos <<= 1;
                    set_size(maxpos, true);
                }
                if (negative) {
                    data[pos-1] = -std::numeric_limits<double>::infinity();
                    negative = false;
                }
                else {
                    data[pos-1] = std::numeric_limits<double>::infinity();
                }
                nan_inf = true;
                break; /// case 'I'...

            case ':': /// reads format a:b:c or a:b
                buffer.seekg(1, std::ios_base::cur);
                /// parse b
                while (buffer.peek() != EOF)
                {
                    switch (buffer.peek())
                    {
                        case ' ':
                        case '\t':
                        buffer.seekg(1, std::ios_base::cur);
                        break;

                        case ':':
                        buffer.seekg(1, std::ios_base::cur);
                        /// parse c
                        while (buffer.peek() != EOF)
                        {
                            switch (buffer.peek())
                            {
                                case ' ':
                                case '\t':
                                    buffer.seekg(1, std::ios_base::cur);
                                    break;

                                default:
                                    buffer.clear();
                                    buffer >> c;
                                    c_parsed = true;
                            }
                        }
                        break;

                        default:
                            buffer.clear();
                            buffer >> b;
                            b_parsed = true;
                    }
                }

                if (c_parsed)
                {
                    /// Adding this margin fixes precision problems in e.g. "0:0.2:3",
                    /// where the last value was 2.8 instead of 3.
                    double eps = std::numeric_limits<double>::epsilon();
                    eps_margin = std::fabs((c - data[pos-1]) / b) * eps;
                    if (b > 0 && c >= data[pos-1])
                    {
                        while (data[pos-1] + b <= c + eps_margin)
                        {
                            if (++pos > maxpos) {
                                maxpos <<= 1;
                                set_size(maxpos, true);
                            }
                            data[pos-1] = data[pos-2] + b;
                        }
                    }
                    else if (b < 0 && c <= data[pos-1])
                    {
                        while (data[pos-1] + b >= c - eps_margin)
                        {
                            if (++pos > maxpos) {
                                maxpos <<= 1;
                                set_size(maxpos, true);
                            }
                            data[pos-1] = data[pos-2] + b;
                        }
                    }
                    else if (b == 0 && c == data[pos-1]) {
                        break;
                    }
                }   /// if (c_parsed)
                else if (b_parsed)
                {
                    double eps = std::numeric_limits<double>::epsilon();
                    eps_margin = std::fabs(b - data[pos-1]) * eps;
                    if (b < data[pos-1])
                    {
                        while (data[pos-1] - 1.0 >= b - eps_margin)
                        {
                            if (++pos > maxpos) {
                                maxpos <<= 1;
                                set_size(maxpos, true);
                            }
                            data[pos-1] = data[pos-2] - 1.0;
                        }
                    }
                    else {
                        while (data[pos-1] + 1.0 <= b + eps_margin)
                        {
                            if (++pos > maxpos) {
                                maxpos <<= 1;
                                set_size(maxpos, true);
                            }
                            data[pos-1] = data[pos-2] + 1.0;
                        }
                    }
                } /// else if (b_parsed)
                else {
                    std::cout << "Vec<double>::set(): Improper data string (a:b)" << std::endl;
                }
                break; /// case ':'

            default:
                if (++pos > maxpos) {
                    maxpos <<= 1;
                    set_size(maxpos, true);
                }
                buffer >> data[pos-1];
                if (negative) {
                    data[pos-1] = -data[pos-1];
                    negative = false;
                }
                break; /// default
        }
    }
    set_size(pos, true);
}



template<>
void Vec<int>::set(const std::string &str)
{
  std::istringstream buffer(replace_commas(str));
  int b = 0;
  int c = 0;
  bool b_parsed = false;
  bool c_parsed = false;
  bool negative = false;
  int pos = 0;
  int maxpos = 10;

  free();
  alloc(maxpos);

  while (buffer.peek() != EOF) {
    switch (buffer.peek()) {
      /// skip spaces and tabs
    case ' ':
    case '\t':
      buffer.seekg(1, std::ios_base::cur);
      break;

      /// skip '+' sign
    case '+':
      /// check for not handled '-' sign
      buffer.seekg(1, std::ios_base::cur);
      break;

      /// check for '-' sign
    case '-':
      buffer.seekg(1, std::ios_base::cur);
      negative = true;
      break;

      /// hexadecimal number or octal number or zero
    case '0':
      buffer.seekg(1, std::ios_base::cur);
      switch (buffer.peek()) {
        // hexadecimal number
      case 'x':
      case 'X':
        buffer.clear();
        buffer.seekg(-1, std::ios_base::cur);
        if (++pos > maxpos) {
          maxpos <<= 1;
          set_size(maxpos, true);
        }
        buffer >> std::hex >> data[pos-1];
        break; /// case 'x'...

        // octal number
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
        buffer.clear();
        buffer.seekg(-1, std::ios_base::cur);
        if (++pos > maxpos) {
          maxpos <<= 1;
          set_size(maxpos, true);
        }
        buffer >> std::oct >> data[pos-1];
        break; /// case '1'...

        /// zero
      case EOF:
      case ' ':
      case '\t':
      case ':':
      case '0':
        buffer.clear();
        buffer.seekg(-1, std::ios_base::cur);
        if (++pos > maxpos) {
          maxpos <<= 1;
          set_size(maxpos, true);
        }
        buffer >> std::dec >> data[pos-1];
        break; /// case EOF...

      default:
        std::cout << "Error: Vec<int>::set(): Improper data string" << std::endl;
      }
      /// check if just parsed data was negative
      if (negative) {
        data[pos-1] = -data[pos-1];
        negative = false;
      }
      break; /// case '0'

      /// decimal number
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      buffer.clear();
      if (++pos > maxpos) {
        maxpos <<= 1;
        set_size(maxpos, true);
      }
      buffer >> std::dec >> data[pos-1];
      /// check if just parsed data was negative
      if (negative) {
        data[pos-1] = -data[pos-1];
        negative = false;
      }
      break; /// case '1'...

      /// parse format a:b:c or a:b
    case ':':
      buffer.seekg(1, std::ios_base::cur);
      /// parse b
      while (buffer.peek() != EOF) {
        switch (buffer.peek()) {
        case ' ':
        case '\t':
          buffer.seekg(1, std::ios_base::cur);
          break;

          /// skip '+' sign
        case '+':
          /// check for not handled '-' sign
          buffer.seekg(1, std::ios_base::cur);
          break;

          /// check for '-' sign
        case '-':
          buffer.seekg(1, std::ios_base::cur);
          negative = true;
          break;

          /// hexadecimal number or octal number or zero
        case '0':
          buffer.seekg(1, std::ios_base::cur);
          switch (buffer.peek()) {
            /// hexadecimal number
          case 'x':
          case 'X':
            buffer.clear();
            buffer.seekg(-1, std::ios_base::cur);
            buffer >> std::hex >> b;
            break; /// case 'x'...

            /// octal number
          case '1':
          case '2':
          case '3':
          case '4':
          case '5':
          case '6':
          case '7':
            buffer.clear();
            buffer.seekg(-1, std::ios_base::cur);
            buffer >> std::oct >> b;
            break; /// case '1'...

            /// zero
          case EOF:
          case ' ':
          case '\t':
          case ':':
          case '0':
            buffer.clear();
            buffer.seekg(-1, std::ios_base::cur);
            buffer >> std::dec >> b;
            break; /// case EOF...

          default:
            std::cout << "Vec<int>::set(): Improper data string (a:b)" << std::endl;
          } /// switch (buffer.peek())
          /// check if just parsed data was negative
          if (negative) {
            b = -b;
            negative = false;
          }
          b_parsed = true;
          break; /// case '0'

          /// decimal number
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
          buffer.clear();
          buffer >> std::dec >> b;
          /// check if just parsed data was negative
          if (negative) {
            b = -b;
            negative = false;
          }
          b_parsed = true;
          break; /// case '1'...

        case ':':
          buffer.seekg(1, std::ios_base::cur);
          /// parse c
          while (buffer.peek() != EOF) {
            switch (buffer.peek()) {
            case ' ':
            case '\t':
              buffer.seekg(1, std::ios_base::cur);
              break;

              /// skip '+' sign
            case '+':
              /// check for not handled '-' sign
              buffer.seekg(1, std::ios_base::cur);
              break;

              /// check for '-' sign
            case '-':
              buffer.seekg(1, std::ios_base::cur);
              negative = true;
              break;

              /// hexadecimal number or octal number or zero
            case '0':
              buffer.seekg(1, std::ios_base::cur);
              switch (buffer.peek()) {
                /// hexadecimal number
              case 'x':
              case 'X':
                buffer.clear();
                buffer.seekg(-1, std::ios_base::cur);
                buffer >> std::hex >> c;
                break; /// case 'x'...

                /// octal number
              case '1':
              case '2':
              case '3':
              case '4':
              case '5':
              case '6':
              case '7':
                buffer.clear();
                buffer.seekg(-1, std::ios_base::cur);
                buffer >> std::oct >> c;
                break; /// case '1'...

                /// zero
              case EOF:
              case ' ':
              case '\t':
              case '0':
                buffer.clear();
                buffer.seekg(-1, std::ios_base::cur);
                buffer >> std::dec >> c;
                break; /// case EOF...

              default:
                std::cout << "Vec<int>::set(): Improper data string (a:b:c)" << std::endl;
              }
              c_parsed = true;
              break; /// case '0'

              /// decimal number
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
              buffer.clear();
              buffer >> std::dec >> c;
              c_parsed = true;
              break;

            default:
              std::cout << "Vec<int>::set(): Improper data string (a:b:c)" << std::endl;
            } /// switch (buffer.peek())
          } /// while (buffer.peek() != EOF)
          /// check if just parsed data was negative
          if (negative) {
            c = -c;
            negative = false;
          }
          break; /// case ':'

        default:
          std::cout << "Vec<int>::set(): Improper data string (a:b)" << std::endl;
        } /// switch (buffer.peek())
      } /// while (buffer.peek() != EOF)

      if (c_parsed) {
        if (b > 0 && c >= data[pos-1]) {
          while (data[pos-1] + b <= c) {
            if (++pos > maxpos) {
              maxpos <<= 1;
              set_size(maxpos, true);
            }
            data[pos-1] = data[pos-2] + b;
          }
        }
        else if (b < 0 && c <= data[pos-1]) {
          while (data[pos-1] + b >= c) {
            if (++pos > maxpos) {
              maxpos <<= 1;
              set_size(maxpos, true);
            }
            data[pos-1] = data[pos-2] + b;
          }
        }
        else if (b == 0 && c == data[pos-1]) {
          break;
        }
        else {
          std::cout << "Vec<int>::set(): Improper data string (a:b:c)" << std::endl;
        }
      } /// if (c_parsed)
      else if (b_parsed) {
        if (b < data[pos-1]) {
          while (data[pos-1] > b) {
            if (++pos > maxpos) {
              maxpos <<= 1;
              set_size(maxpos, true);
            }
            data[pos-1] = data[pos-2] - 1;
          }
        }
        else {
          while (data[pos-1] < b) {
            if (++pos > maxpos) {
              maxpos <<= 1;
              set_size(maxpos, true);
            }
            data[pos-1] = data[pos-2] + 1;
          }
        }
      } /// else if (b_parsed)
      else {
        std::cout << "Vec<int>::set(): Improper data string (a:b)" << std::endl;
      }
      break; /// case ':'

    default:
      std::cout << "Vec<int>::set(): Improper data string" << std::endl;
    }
  }
  /// resize the parsed vector to its final length
  set_size(pos, true);
}


template<class Num_T>
void Vec<Num_T>::set(const std::string &str)
{
    std::cout << "Vec::set(): Only `double' and `int' types supported" << std::endl;
}


template<class Num_T>
std::string Vec<Num_T>::replace_commas(const std::string &str_in)
{
    /// copy an input sting into a local variable str
    std::string str(str_in);
    /// find first occurence of comma in string str
    std::string::size_type index = str.find(',', 0);
    while (index != std::string::npos) {
        /// replace character at position index with space
        str.replace(index, 1, 1, ' ');
        /// find next occurence of comma in string str
        index = str.find(',', index);
    }
    return str;
}


