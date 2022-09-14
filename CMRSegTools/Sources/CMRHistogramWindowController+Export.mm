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
//  CMRHistogramWindowController+Export.m
//  CMRSegTools
//
//  Created by Alessandro Volz on 1/8/18.
//  Copyright © 2018 Creatis. All rights reserved.
//

#import "CMRHistogramWindowController+Export.h"
#import "CMRHiResFloatVolumeData.h"
#import "OsiriX+CMRSegTools.h"
#import <OsiriX/OSIVolumeWindow.h>
#import <OsiriX/OSIROIManager.h>
#import <OsiriX/ViewerController.h>
#import <OsiriX/DCMView.h>

#include <map>

@implementation CMRHistogramWindowController (Export)

- (IBAction)exportRegions:(id)sender {
    NSSavePanel *sp = [NSSavePanel savePanel];
    sp.title = NSLocalizedString(@"Export CMRSegTools Regions", nil);
    sp.allowedFileTypes = @[@"csv"];
    sp.canCreateDirectories = YES;
    [sp beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSFileHandlingPanelOKButton)
            [self exportRegionsToURL:sp.URL];
    }];
}

- (void)exportRegionsToURL:(NSURL *)url {
    OSIROIManager *rm = [self.volumeWindow ROIManager];
    
    OSIFloatVolumeData *vd = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CMR42EmulationMode"])
        vd = [[[CMRHiResFloatVolumeData alloc] initWithFloatVolumeData:vd widthSubdivisions:4 heightSubdivisions:4 depthSubdivisions:1] autorelease];

    N3AffineTransform vt = N3AffineTransformInvert(vd.volumeTransform);
    
    struct p {
        NSUInteger x, y, z;
        p(NSUInteger x, NSUInteger y, NSUInteger z) : x(x), y(y), z(z) {}
        p(const OSIROIMaskIndex &v) : x(v.x), y(v.y), z(v.z) {}
        // afin de pouvoir utiliser cette structure comme clef d'un map, nous définissons un comparateur
        bool operator<(const p& o) const {
            return std::tie(x, y, z) < std::tie(o.x, o.y, o.z);
        }
    };
    
    struct f {
        BOOL mi, nr;
        f() { mi = nr = NO; }
    };
    
    std::map<p,f> pf;
    
    NSInteger movieIndex = [[self.volumeWindow viewerController] curMovieIndex];
    for (NSUInteger pixIndex = 0; pixIndex < [[[self.volumeWindow.viewerController imageView] dcmPixList] count]; ++pixIndex) {
        for (NSValue *miv in [[[rm CMRFirstROIWithName:@"myocardium" movieIndex:movieIndex pixIndex:pixIndex] ROIMaskForFloatVolumeData:vd] maskIndexes])
            pf[miv.OSIROIMaskIndexValue]; // afin que tous les points du myocarde soyent dans le map
        for (NSValue *miv in [[[rm CMRFirstROIWithName:@"segmented" movieIndex:movieIndex pixIndex:pixIndex] ROIMaskForFloatVolumeData:vd] maskIndexes])
            pf[miv.OSIROIMaskIndexValue].mi = YES;
        for (NSValue *miv in [[[rm CMRFirstROIWithName:@"no-reflow" movieIndex:movieIndex pixIndex:pixIndex] ROIMaskForFloatVolumeData:vd] maskIndexes])
            pf[miv.OSIROIMaskIndexValue].nr = YES;
    }
    
    NSMutableString *csv = [NSMutableString stringWithFormat:@"CMRSegTools v%@ regions export\n", [[[NSBundle bundleForClass:self.class] infoDictionary] valueForKey:(id)kCFBundleVersionKey]];
    
    [csv appendString:@"LABELS,3\n"];
    [csv appendString:@"0,non-MI\n"];
    [csv appendString:@"1,MI\n"];
    [csv appendString:@"2,NR\n"];
    
    [csv appendFormat:@"POINTS,%lu\n", pf.size()];
    for (auto const &pfi : pf) {
        N3Vector pfip = N3VectorApplyTransform(N3VectorMake(pfi.first.x, pfi.first.y, pfi.first.z), vt);

        NSString *flags = @"";
        if (pfi.second.mi) {
            if (!pfi.second.nr)
                flags = @"1";
            else flags = @"1 2"; // ceci ne devrait jamais se passer
        } else {
            if (!pfi.second.nr)
                flags = @"0";
            else flags = @"2";
        }
        
        [csv appendFormat:@"%.15f,%.15f,%.15f,%@,%lu,%lu,%lu\n", pfip.x, pfip.y, pfip.z, flags, (unsigned long)pfi.first.x, (unsigned long)pfi.first.y, (unsigned long)pfi.first.z];
    }
    
    [csv writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

//+ (NSString *)quoteStringForCSV:(NSString *)str {
//    if (!str)
//        return @"";
//    if ([str rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@",\"\n"]].location == NSNotFound)
//        return str;
//    return [NSString stringWithFormat:@"\"%@\"", [str stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
//}

@end
