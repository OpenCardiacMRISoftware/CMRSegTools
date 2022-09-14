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
/*
 -----------------------------------------------------------------------------
 Name        : NSString Utilities.
 
 Description : Category for NSString.
 
 Author      : William A. Romero R. <romero@creatis.insa-lyon.fr>
                                    <contact@waromero.com>
 
 CREATIS
 Copyright (C) 2014
 
 You should have received a copy  of the CMRSegTools license along with this
 program. Further information:
 
 http://www.creatis.insa-lyon.fr/
 
 -----------------------------------------------------------------------------
 */

#import <Cocoa/Cocoa.h>

@interface NSString (CRMSegTools_Utils)

- (NSData*) getSerialNumberBytes;

@end
