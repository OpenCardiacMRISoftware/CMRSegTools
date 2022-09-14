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
//
//  Parser.m
//  CMRSegTools
//
//  Created by Coralie Vandroux on 4/30/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "Parser.h"

@implementation Parser

@synthesize Slices;
@synthesize Epi;
@synthesize Endo;
@synthesize Enhanced;
@synthesize Ref;
@synthesize NR;
@synthesize Points;
@synthesize PointCoord;
@synthesize StudyUid;
@synthesize currentProperty;
@synthesize parser;
@synthesize HaveEndo;
@synthesize HaveEpi;
@synthesize HaveEnhanced;
@synthesize HaveRef;
@synthesize HaveNR;
@synthesize subPixels;

-(Parser *)init{
    return self;
}
- (void)parserDidStartDocument:(NSXMLParser *)parser {
    currentKey = [[NSMutableArray alloc]initWithCapacity:0];
	currentCount = [[NSMutableArray alloc]initWithCapacity:0];
    
    Slices = [[NSMutableArray alloc]initWithCapacity:0];
    [Slices addObject:@"Slices"];
    StudyUid = @"NO";
    
    PointCoord = [[NSMutableArray alloc]initWithCapacity:0];
    Points = [[NSMutableArray alloc]initWithCapacity:0];
    Endo = [[NSMutableArray alloc]initWithCapacity:0];
    Epi = [[NSMutableArray alloc]initWithCapacity:0];
    Enhanced = [[NSMutableArray alloc]initWithCapacity:0];
    Ref = [[NSMutableArray alloc]initWithCapacity:0];
    NR = [[NSMutableArray alloc]initWithCapacity:0];
    
    HaveEndo = [[NSMutableArray alloc]initWithCapacity:0];
    HaveEpi = [[NSMutableArray alloc]initWithCapacity:0];
    HaveEnhanced = [[NSMutableArray alloc]initWithCapacity:0];
    HaveRef = [[NSMutableArray alloc]initWithCapacity:0];
    HaveNR = [[NSMutableArray alloc]initWithCapacity:0];

    nbPoints = -1;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
    if ([elementName isEqualToString:@"Hash:item"])
    {
        // On recherche le studyUid
        if ( [[attributeDict objectForKey:@"Hash:key"] isEqualToString:@"StudyUid"] )
        {
            StudyUid = @"YES";
            self.currentProperty = [NSMutableString string];
        }
        else
        {
            StudyUid = @"NO";
        }
        
        if ( [[attributeDict objectForKey:@"Hash:key"] isEqualToString:@"SubpixelResolution"] )
        {
            SubpixelResolution = @"YES";
            self.currentProperty = [NSMutableString string];
        }

        // On recherche les éléments qui ont un attribut count
        if ( [[attributeDict objectForKey:@"Hash:count"] isNotEqualTo:nil] )
        {
            [currentKey addObject:[attributeDict objectForKey:@"Hash:key"]];
            [currentCount addObject:[attributeDict objectForKey:@"Hash:count"]];
            parent = @"YES";
        }
        else
        {
            parent = @"NO";
        }
        
        if ([[attributeDict objectForKey:@"Hash:key"] isEqualToString:@"Points"] && [[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saepicardialContour"])
        {
            nbPoints = [[attributeDict objectForKey:@"List:count"] intValue]*2;
        }
        if ([[attributeDict objectForKey:@"Hash:key"] isEqualToString:@"Points"] && [[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saendocardialContour"])
        {
            nbPoints = [[attributeDict objectForKey:@"List:count"] intValue]*2;
        }
        if ([[attributeDict objectForKey:@"Hash:key"] isEqualToString:@"Points"] && [[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saEnhancementReferenceMyoContour"])
        {
            nbPoints = [[attributeDict objectForKey:@"List:count"] intValue]*2;
        }
        if ([[attributeDict objectForKey:@"Hash:key"] isEqualToString:@"Points"] && [[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saReferenceMyoContour"])
        {
            nbPoints = [[attributeDict objectForKey:@"List:count"] intValue]*2;
        }
        if ([[attributeDict objectForKey:@"Hash:key"] isEqualToString:@"Points"] && [[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"noReflowAreaContour"])
        {
            nbPoints = [[attributeDict objectForKey:@"List:count"] intValue]*2;
        }
    }
    else
    {
        parent = @"NO";
    }
    
    if ([elementName isEqualToString:@"Point:x"] || [elementName isEqualToString:@"Point:y"])
    {
        if ([[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saepicardialContour"])
        {
            parent = @"NO";
            self.currentProperty = [NSMutableString string];
            nbPoints = nbPoints-1;
        }
        if ([[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saendocardialContour"])
        {
            parent = @"NO";
            self.currentProperty = [NSMutableString string];
            nbPoints = nbPoints-1;
        }
        if ([[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saEnhancementReferenceMyoContour"])
        {
            parent = @"NO";
            self.currentProperty = [NSMutableString string];
            nbPoints = nbPoints-1;
        }
        if ([[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saReferenceMyoContour"])
        {
            parent = @"NO";
            self.currentProperty = [NSMutableString string];
            nbPoints = nbPoints-1;
        }
        if ([[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"noReflowAreaContour"])
        {
            parent = @"NO";
            self.currentProperty = [NSMutableString string];
            nbPoints = nbPoints-1;
        }
        
    }
    
    // On ajoute dans Slices les identifiants de toutes les slices que l'on parcours
    if ([currentKey count]>1)
    {
        NSString *KeyAt0 = [currentKey objectAtIndex:0];
        if ([KeyAt0 isEqualToString:@"ImageStates"] && [[currentKey objectAtIndex:1] isNotEqualTo:[Slices objectAtIndex:[Slices count]-1]])
        {
            [Slices addObject:[currentKey objectAtIndex:[currentKey count]-1]];
            index = [Slices count]-1;
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"Hash:item"])
    {
        // Si on a trouvé le studyUid on l'enregistre en position 0 dans Slices
        if ([StudyUid isEqualToString:@"YES"])
        {
            [Slices replaceObjectAtIndex:0 withObject:self.currentProperty];
            self.currentProperty = nil;
        }
        else
        {
            StudyUid = @"NO";
        }
        
        if ([SubpixelResolution isEqualToString:@"YES"])
        {
            subPixels = [self.currentProperty intValue];
            self.currentProperty = nil;
            SubpixelResolution = @"NO";
        }
        
        // On suit l'arbre des clés
        if ([parent isEqualToString:@"NO"] && [currentCount count] !=0)
        {
            NSInteger numDer = [[currentCount objectAtIndex:[currentCount count]-1] intValue];
            if (numDer == 0)
            {
                [currentCount removeLastObject];
                [currentKey removeLastObject];
            }
            else
            {
                numDer = numDer-1;
                [currentCount replaceObjectAtIndex:[currentKey count]-1 withObject:[NSString stringWithFormat:@"%ld", (long)numDer]];
            }
            
        }
        if ([parent isEqualToString:@"YES"] && [currentCount count] >1)
        {
            NSInteger num = [[currentCount objectAtIndex:[currentCount count]-2] intValue];
            if (num == 0)
            {
                [currentCount removeLastObject];
                [currentKey removeLastObject];
            }
            else
            {
                num = num-1;
                [currentCount replaceObjectAtIndex:[currentKey count]-2 withObject:[NSString stringWithFormat:@"%ld", (long)num]];
            }
        }
        if ([currentCount count] !=0)
        {
            NSInteger n = [[currentCount objectAtIndex:[currentCount count]-1] intValue];
            if (n == 0)
            {
                [currentCount removeLastObject];
                [currentKey removeLastObject];
            }
        }
    }
    
    if ([elementName isEqualToString:@"Point:x"] || [elementName isEqualToString:@"Point:y"])
    {
        if ([[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saepicardialContour"])
        {
            if (nbPoints>0)
            {
                [PointCoord addObject:self.currentProperty];
                self.currentProperty = nil;
                if ([elementName isEqualToString:@"Point:y"])
                {
                    [Points addObject:[[NSMutableArray alloc] initWithArray:PointCoord]];
                    [PointCoord removeAllObjects];
                    PointCoord = [[NSMutableArray alloc] initWithCapacity:0];
                }
            }
            else if (nbPoints==0)
            {
                [Points addObject:[[NSMutableArray alloc] initWithArray:PointCoord]];
                [PointCoord removeAllObjects];
                PointCoord = [[NSMutableArray alloc] initWithCapacity:0];
                
                [Epi addObject:[[NSMutableArray alloc] initWithArray:Points]];
                [Points removeAllObjects];
                Points = [[NSMutableArray alloc] initWithCapacity:0];
                [HaveEpi addObject:[Slices objectAtIndex:index]];
                nbPoints = -1;
            }
        }
        if ([[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saendocardialContour"])
        {
            if (nbPoints>0)
            {
                [PointCoord addObject:self.currentProperty];
                self.currentProperty = nil;
                if ([elementName isEqualToString:@"Point:y"])
                {
                    [Points addObject:[[NSMutableArray alloc] initWithArray:PointCoord]];
                    [PointCoord removeAllObjects];
                    PointCoord = [[NSMutableArray alloc] initWithCapacity:0];
                }
            }
            else if (nbPoints==0)
            {
                [Points addObject:[[NSMutableArray alloc] initWithArray:PointCoord]];
                [PointCoord removeAllObjects];
                PointCoord = [[NSMutableArray alloc] initWithCapacity:0];
                
                [Endo addObject:[[NSMutableArray alloc] initWithArray:Points]];
                [Points removeAllObjects];
                Points = [[NSMutableArray alloc] initWithCapacity:0];
                [HaveEndo addObject:[Slices objectAtIndex:index]];
                nbPoints = -1;
            }
        }
        if ([[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saEnhancementReferenceMyoContour"])
        {
            if (nbPoints>0)
            {
                [PointCoord addObject:self.currentProperty];
                self.currentProperty = nil;
                if ([elementName isEqualToString:@"Point:y"])
                {
                    [Points addObject:[[NSMutableArray alloc] initWithArray:PointCoord]];
                    [PointCoord removeAllObjects];
                    PointCoord = [[NSMutableArray alloc] initWithCapacity:0];
                }
            }
            else if (nbPoints==0)
            {
                [Points addObject:[[NSMutableArray alloc] initWithArray:PointCoord]];
                [PointCoord removeAllObjects];
                PointCoord = [[NSMutableArray alloc] initWithCapacity:0];
                
                [Enhanced addObject:[[NSMutableArray alloc] initWithArray:Points]];
                [Points removeAllObjects];
                Points = [[NSMutableArray alloc] initWithCapacity:0];
                [HaveEnhanced addObject:[Slices objectAtIndex:index]];
                nbPoints = -1;
            }
        }
        if ([[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"saReferenceMyoContour"])
        {
            if (nbPoints>0)
            {
                [PointCoord addObject:self.currentProperty];
                self.currentProperty = nil;
                if ([elementName isEqualToString:@"Point:y"])
                {
                    [Points addObject:[[NSMutableArray alloc] initWithArray:PointCoord]];
                    [PointCoord removeAllObjects];
                    PointCoord = [[NSMutableArray alloc] initWithCapacity:0];
                }
            }
            else if (nbPoints==0)
            {
                [Points addObject:[[NSMutableArray alloc] initWithArray:PointCoord]];
                [PointCoord removeAllObjects];
                PointCoord = [[NSMutableArray alloc] initWithCapacity:0];
                
                [Ref addObject:[[NSMutableArray alloc] initWithArray:Points]];
                [Points removeAllObjects];
                Points = [[NSMutableArray alloc] initWithCapacity:0];
                [HaveRef addObject:[Slices objectAtIndex:index]];
                nbPoints = -1;
            }
        }
        if ([[currentKey objectAtIndex:[currentKey count]-1] isEqualToString:@"noReflowAreaContour"])
        {
            if (nbPoints>0)
            {
                [PointCoord addObject:self.currentProperty];
                self.currentProperty = nil;
                if ([elementName isEqualToString:@"Point:y"])
                {
                    [Points addObject:[[NSMutableArray alloc] initWithArray:PointCoord]];
                    [PointCoord removeAllObjects];
                    PointCoord = [[NSMutableArray alloc] initWithCapacity:0];
                }
            }
            else if (nbPoints==0)
            {
                [Points addObject:[[NSMutableArray alloc] initWithArray:PointCoord]];
                [PointCoord removeAllObjects];
                PointCoord = [[NSMutableArray alloc] initWithCapacity:0];
                
                [NR addObject:[[NSMutableArray alloc] initWithArray:Points]];
                [Points removeAllObjects];
                Points = [[NSMutableArray alloc] initWithCapacity:0];
                [HaveNR addObject:[Slices objectAtIndex:index]];
                nbPoints = -1;
            }
        }
        
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    
    if(self.currentProperty == nil)
        
        self.currentProperty = [[NSMutableString alloc] init];
    
    [self.currentProperty appendString:string];
}
@end
