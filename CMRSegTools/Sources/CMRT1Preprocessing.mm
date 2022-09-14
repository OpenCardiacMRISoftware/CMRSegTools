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
//  CMRT1Preprocessing.mm
//  CMRSegTools
//
//  Created by Alessandro Volz on 5/11/16.
//  Copyright © 2016 volz.io. All rights reserved.
//

#import "CMRT1Preprocessing.h"
#import "CMRSegTools+Constants.h"
#import <OsiriX/NSFileManager+N2.h>
#import <OsiriX/DCM/DCMObject.h>
#import <dcmtk/dcmdata/dcfilefo.h>
#import <dcmtk/dcmimgle/dcmimage.h>
#import <dcmtk/dcmdata/dcuid.h>

@implementation CMRT1Preprocessing (CPP)

- (NSArray<NSURL *> *)clone:(NSArray<CMRT1PreprocessingPic *> *)pix seriesDescription:(NSString *)seriesDescription seriesNumber:(NSUInteger)seriesNumber intoTmpDir:(NSURL *)tmpDir error:(NSError **)error {
    NSString *outputDirPath = [[NSFileManager defaultManager] tmpFilePathInDir:tmpDir.path];
    [[NSFileManager defaultManager] confirmDirectoryAtPath:outputDirPath];
    
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    NSUInteger c = 0;
    
    char temp[65];
    dcmGenerateUniqueIdentifier(temp, [[DCMObject rootUID] UTF8String]);
    NSString *seriesInstanceUID = [NSString stringWithUTF8String:temp];

    NSString *seriesNumberString = [NSString stringWithFormat:@"%lu", (unsigned long)seriesNumber];
    
    DcmFileFormat ff;
    NSURL *ffurl = nil;
    DcmItem *ffe = nil;
    DicomImage *ffi = nil;
    @try {
        for (CMRT1PreprocessingPic *p in pix) {
            if (![ffurl isEqual:p.url]) {
                if (ffi)
                    delete ffi;
                ff.loadFile([(ffurl = p.url) fileSystemRepresentation]);
                ffe = ff.getItem(1); // element 0 contains (0002,****) and element 1 contains all the rest
                ffi = new DicomImage(&ff, EXS_Unknown);
                if (ffi->getStatus() != EIS_Normal) {
                    if (error) *error = [NSError errorWithDomain:CMRSegToolsErrorDomain code:0 userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Data error", nil),
                                                                                                           NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:NSLocalizedString(@"Unable to read image at %@", nil), p.url.path] }];
                    return nil;
                }
            }
            
            if (ffi->getFrameCount() > 1) { // currently, we don't support enhanced DICOM
                if (error) *error = [NSError errorWithDomain:CMRSegToolsErrorDomain code:0 userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Enhanced DICOM file", nil),
                                                                                                       NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Enhanced DICOM is currently unsupported by CMRT1Preprocessing.", nil) }];
                return nil;
            }
            
            ++c;
            NSString *cString = [NSString stringWithFormat:@"%lu", (unsigned long)c];
            
            DcmFileFormat off;
            DcmDataset *ods = off.getDataset();

            // copy the pixels // we're just copying the raw data later
//            ffi->writeFrameToDataset(*offds, ffi->getDepth(), p.frame);
            
            // copy generic tags
            for (unsigned int i = 0; i < ffe->card(); ++i) {
                DcmElement *e = ffe->getElement(i);
                
//                NSLog(@"%04X,%04X", tmpElement->getGTag(), tmpElement->getETag());
                
//                if (e->getGTag() == 0x5200) // we skip group 5200
//                    continue;
//                if (e->getGTag() == 0x7fe0 && e->getETag() == 0x0010) // we skip pixel data
//                    continue;
                
                ods->insert((DcmElement *)e->clone());
            }

            DcmItem *oi = off.getItem(1);
            
            // 0008,0018 SOPInstanceUID
            dcmGenerateUniqueIdentifier(temp, [[DCMObject rootUID] UTF8String]);
            oi->putAndInsertString(DcmTagKey(0x0008, 0x0018), temp);

            // 0020,000e SeriesInstanceUID
            oi->putAndInsertString(DcmTagKey(0x0020, 0x000e), seriesInstanceUID.UTF8String);

            // 0020,0011 SeriesNumber
            oi->putAndInsertString(DcmTagKey(0x0020, 0x0011), seriesNumberString.UTF8String);

            // 0008,103e SeriesDescription
            oi->putAndInsertString(DcmTagKey(0x0008,0x103e), seriesDescription.UTF8String);
            
            // 0020,0012 AcquisitionNumber
            oi->putAndInsertString(DcmTagKey(0x0020, 0x0012), cString.UTF8String);
            
            // 0020,0013 InstanceNumber
            oi->putAndInsertString(DcmTagKey(0x0020, 0x0013), cString.UTF8String);
            
            // 0020,0032 ImagePositionPatient
            // 0020,0037 ImageOrientationPatient
            // 0020,0052 FrameofReferenceUID
            // 0020,1041 SliceLocation
            // 0028,0030 PixelSpacing

            // save
            NSString* outputFilePath = [outputDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.dcm", (int)c]];
            off.saveFile(outputFilePath.fileSystemRepresentation, EXS_LittleEndianExplicit, EET_ExplicitLength);
            
            [urls addObject:[NSURL fileURLWithPath:outputFilePath]];
        }
    } @catch (...) {
        @throw;
    } @finally {
        if (ffi)
            delete ffi;
    }
    
    return urls;
}

@end
