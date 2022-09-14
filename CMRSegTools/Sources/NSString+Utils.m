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

#import "NSString+Utils.h"

@implementation NSString (CRMSegTools_Utils)

#pragma mark -
- (NSData*) getSerialNumberBytes
{
	static const unsigned char offset_0 = '0';
	static const unsigned char offset_A = 'A';
	static const unsigned char offset_A16 = offset_A - 10;
	static const unsigned char offset_a = 'a';
	static const unsigned char offset_a16 = offset_a - 10;
    
	NSString* cleaned = [[self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"-" withString:@""];
	if ([cleaned length] != 32)
		return [NSData data];
	
	unsigned char* bytes = (unsigned char*) malloc(16);
	if (bytes == NULL)
		return [NSData data];
    
	unsigned char* b = bytes;
	const char* ptr = [cleaned UTF8String];
	for (int i=0; i<16; i++) {
		unsigned char highNibble = *ptr++;
		if (highNibble >= offset_a)
            highNibble -= offset_a16;
		else if (highNibble >= offset_A)
            highNibble -= offset_A16;
		else
            highNibble -= offset_0;
        
		unsigned char lowNibble = *ptr++;
		if (lowNibble >= offset_a)
            lowNibble -= offset_a16;
		else if (lowNibble >= offset_A)
            lowNibble -= offset_A16;
		else
            lowNibble -= offset_0;
		
		*b++ = (highNibble << 4) + lowNibble;
	}
	
	return [NSData dataWithBytesNoCopy:bytes length:16];
}

@end
