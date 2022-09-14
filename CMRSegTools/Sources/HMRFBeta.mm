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
//  HMRFBeta.m
//  CMRSegToolsPlugin
//
//  Created by Coralie Vandroux on 8/14/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "HMRFBeta.h"

std::vector<LabelGeometryImageFilterType::LabelIndexType> contour;
std::vector<LabelGeometryImageFilterType::LabelIndexType> contour2;
std::vector<LabelGeometryImageFilterType::LabelIndexType> contour3;

@interface HMRFBeta ()
@property (nonatomic, readwrite, retain) OSIVolumeWindow *volumeWindow;
@end

@implementation HMRFBeta

@synthesize volumeWindow = _volumeWindow;

#ifdef DEBUG_HMRF_DEV
////////// Collection of methods for tests
//////////////////////////////////////////////////////////////////////////////////////////

// method to display ROI mask
-(void)showROI:(OSIROIMask*) b
{//i doit étre inférieur au nombre de tranche
    NSArray *arrayMaskRunsTest = [b maskRuns];
    ImageTypeFloat2D::Pointer imageTest=[self WrapImageFloat2D];
    ImageTypeFloat2D::SizeType size=imageTest->GetLargestPossibleRegion().GetSize();
    float array[size[0]][size[1]];
    ImageTypeFloat2D::IndexType pixelIndexTest;
    for (NSValue *valueTest in arrayMaskRunsTest) {
        OSIROIMaskRun runTest;//cette classe permet le parcours d'un masque pixel par pixel elle correspondant à une segment appartenant à une ligne dont les élements sont accesibles par (run.widthRange)définit par son début (location) et sa longueur (length), elle donne aussi son index suivant la hauteur run.heightIndex et et la profondeur run.depthIndex.
        [valueTest getValue:&runTest];
        NSRange rangeTest =  runTest.widthRange;
        for (int i = 0; i<rangeTest.length; i++) {
            pixelIndexTest[0] = rangeTest.location+i;   // x position
            pixelIndexTest[1] = runTest.heightIndex;    // y position
            array[pixelIndexTest[0]][pixelIndexTest[1]]=imageTest->GetPixel(pixelIndexTest);
            imageTest->SetPixel(pixelIndexTest,200);
        }
        // [[self.volumeWindow viewerController] setImageIndex:SliceIndex];
    }
    //[self copyImage:imageTest];
    for (NSValue *valueTest in arrayMaskRunsTest) {
        OSIROIMaskRun runTest;//cette classe permet le parcours d'un masque pixel par pixel elle correspondant à une segment appartenant à une ligne dont les élements sont accesibles par (run.widthRange)définit par son début (location) et sa longueur (length), elle donne aussi son index suivant la hauteur run.heightIndex et et la profondeur run.depthIndex.
        [valueTest getValue:&runTest];
        NSRange rangeTest =  runTest.widthRange;
        for (int i = 0; i<rangeTest.length; i++) {
            pixelIndexTest[0] = rangeTest.location+i;   // x position
            pixelIndexTest[1] = runTest.heightIndex;    // y position
            imageTest->SetPixel(pixelIndexTest,array[pixelIndexTest[0]][pixelIndexTest[1]]);
        }
        // [[self.volumeWindow viewerController] setImageIndex:SliceIndex];
    }
    
}
 
-(ViewerController*)copyImage:(ImageTypeFloat2D::Pointer) b
{
    double voxelSpacing[2];
    voxelSpacing[0] = 1;
    voxelSpacing[1] = 1;
    ImageTypeFloat2D::SizeType  size= b->GetLargestPossibleRegion().GetSize();
    ImageTypeFloat2D::IndexType PixelIndex;
    float *imageptr= b->GetBufferPointer();
    DCMPix *PixTest= [[DCMPix alloc] initWithData:imageptr :32 :size[0] :size[1] :voxelSpacing[0] :voxelSpacing[1] :0 :0 :0];
    float *fImageA=[PixTest fImage];
    for(int y=0;y<size[1];y++){
        for(int x=0;x<size[0];x++){
            PixelIndex[0]=x;
            PixelIndex[1]=y;
            int a=b->GetPixel(PixelIndex);
            fImageA[PixTest.pwidth*y+x]=a;
        }
    }
    NSData *volumeData =[[NSMutableData alloc] autorelease];
    volumeData= [[self.volumeWindow viewerController]volumeData];
    NSMutableArray  *pixList        = [[NSMutableArray alloc] initWithCapacity:0];
    [pixList addObject: PixTest];
    NSMutableArray *newFileArray = [NSMutableArray arrayWithArray:[[[self.volumeWindow viewerController] fileList] subarrayWithRange:NSMakeRange(0,1)]];
    ViewerController *view1=[[ViewerController alloc] newWindow:pixList :newFileArray :volumeData];
    return view1;
}

-(ImageTypeFloat2D::Pointer)copyImage:(ImageTypeFloat3D::Pointer) b atSlice:(int)j
{
    double voxelSpacing[2];
    voxelSpacing[0] = 1;
    voxelSpacing[1] = 1;
    ImageTypeFloat3D::SizeType  size= b->GetLargestPossibleRegion().GetSize();
    ImageTypeFloat3D::IndexType PixelIndex;
    //float *imageptr= b->GetBufferPointer();
    long sizeptr = sizeof( float) * voxelSpacing[0]*voxelSpacing[1];
    float *imageptr =new float[sizeptr];
    NSMutableArray  *pixList        = [[[NSMutableArray alloc] initWithCapacity:0]autorelease];
    //    NSMutableData   *volumeData     = [[[NSMutableData alloc] initWithLength:0]autorelease];
    //    long mem            = size[0]*size[1]*size[2]* 4; // 4 Byte = 32 Bit Farbwert
    //    float *fVolumePtr   = new float(mem);
    //    if( fVolumePtr)
    //    {
    //        volumeData = [[NSMutableData alloc] initWithBytesNoCopy:fVolumePtr length:mem freeWhenDone:YES];
    //    }
    NSData *volumeData =[[NSMutableData alloc] autorelease];
    volumeData= [[self.volumeWindow viewerController]volumeData];
    NSMutableArray *newFileArray = [NSMutableArray arrayWithArray:[[[self.volumeWindow viewerController] fileList] subarrayWithRange:NSMakeRange(0,1)]];
    //DCMPix *PixTest=[[[self.volumeWindow viewerController] pixList] objectAtIndex:1];
    DCMPix *PixTest= [[DCMPix alloc] initWithData:imageptr :32 :size[0] :size[1] :voxelSpacing[0] :voxelSpacing[1] :0 :0 :0];
    float *fImageA=[PixTest fImage];
    for(int y=0;y<size[1];y++){
        for(int x=0;x<size[0];x++){
            PixelIndex[0]=x;
            PixelIndex[1]=y;
            PixelIndex[2]=j;
            fImageA[PixTest.pwidth*y+x]=b->GetPixel(PixelIndex);
        }
    }
    [pixList addObject: PixTest];
    viewControl1=[ViewerController newWindow:pixList :newFileArray :volumeData];
    long SliceIndex1 = [[viewControl1 imageView]curImage];
    
    ImageTypeFloat2D::Pointer wrapImage1;
    ImportFilterTypeFloat2D::Pointer importFilter1 = ImportFilterTypeFloat2D::New();
    ImportFilterTypeFloat2D::SizeType size1;
    ImportFilterTypeFloat2D::IndexType start1;
    ImportFilterTypeFloat2D::RegionType region1;
    
    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    
    size1[0] = [firstPix pwidth];
    size1[1] = [firstPix pheight];
    
    long bufferSize1 = size[0] * size[1];
    start1.Fill(0);
    region1.SetIndex(start1);
    region1.SetSize(size1);
    
    double voxelSpacing1[3];
    double origin1[3];
    origin1[0] = [firstPix originX];
    origin1[1] = [firstPix originY];
    voxelSpacing1[0] = 1;
    voxelSpacing1[1] = 1;
    
    importFilter1->SetRegion(region1);
    importFilter1->SetSpacing(voxelSpacing1);
    importFilter1->SetImportPointer([viewControl1 volumePtr]+bufferSize1*SliceIndex1 , bufferSize1, false);// do not overwrite original data
    
    wrapImage1 = importFilter1->GetOutput();
    wrapImage1->Update();
    return wrapImage1;
    
}
-( NSMutableArray*)initWithImage:(ImageTypeFloat3D::Pointer) b  atSlice:(int)j
{
    double voxelSpacing[2];
    voxelSpacing[0] = 1;
    voxelSpacing[1] = 1;
    ImageTypeFloat3D::SizeType  size= b->GetLargestPossibleRegion().GetSize();
    ImageTypeFloat3D::IndexType PixelIndex;
    //float *imageptr= b->GetBufferPointer();
    long sizeptr = sizeof( float) * voxelSpacing[0]*voxelSpacing[1];
    float *imageptr =new float[sizeptr];
    NSMutableArray  *pixList        = [[[NSMutableArray alloc] initWithCapacity:0]autorelease];
    //    NSMutableData   *volumeData     = [[[NSMutableData alloc] initWithLength:0]autorelease];
    //    long mem            = size[0]*size[1]*size[2]* 4; // 4 Byte = 32 Bit Farbwert
    //    float *fVolumePtr   = new float(mem);
    //    if( fVolumePtr)
    //    {
    //        volumeData = [[NSMutableData alloc] initWithBytesNoCopy:fVolumePtr length:mem freeWhenDone:YES];
    //    }
    NSData *volumeData =[[NSMutableData alloc] autorelease];
    volumeData= [[self.volumeWindow viewerController]volumeData];
    //NSMutableArray *newFileArray = [NSMutableArray arrayWithArray:[[[self.volumeWindow viewerController] fileList] subarrayWithRange:NSMakeRange(0,10)]];
    //DCMPix *PixTest=[[[self.volumeWindow viewerController] pixList] objectAtIndex:1];
    DCMPix *PixTest= [[DCMPix alloc] initWithData:imageptr :32 :size[0] :size[1] :voxelSpacing[0] :voxelSpacing[1] :0 :0 :0];
    float *fImageA=[PixTest fImage];
    for(int y=0;y<size[1];y++){
        for(int x=0;x<size[0];x++){
            PixelIndex[0]=x;
            PixelIndex[1]=y;
            PixelIndex[2]=j;
            fImageA[PixTest.pwidth*y+x]=b->GetPixel(PixelIndex);
        }
    }
    [pixList addObject: PixTest];
    return pixList;
    //    ViewerController *viewerControl=[[ViewerController alloc] newWindow:pixList :newFileArray :volumeData];
    //    return viewerControl;
}
-(void)addImage:(ImageTypeFloat3D::Pointer) b toPixList:( NSMutableArray*) pixList atSlice:(int)j
{
    long sizeptr = sizeof( float);
    float *imageptr =new float[sizeptr];
    ImageTypeFloat3D::SizeType size= b->GetLargestPossibleRegion().GetSize();
    ImageTypeFloat3D::IndexType PixelIndex;
    DCMPix *Pix= [[DCMPix alloc] initWithData:imageptr :32 :size[0] :size[1] :1 :1 :0 :0 :0];
    float *fImageA=[Pix fImage];
    for(int y=0;y<size[1];y++){
        for(int x=0;x<size[0];x++){
            PixelIndex[0]=x;
            PixelIndex[1]=y;
            PixelIndex[2]=j;
            fImageA[Pix.pwidth*y+x]=b->GetPixel(PixelIndex);
        }
    }
    
    [pixList addObject:Pix];
}
-(void)visualize:(ImageTypeFloat3D::Pointer) img withOldImage:(ImageTypeFloat2D::Pointer) imgOld atIndex:(int)j
{
    //    double voxelSpacing[2];
    //    voxelSpacing[0] = 1;
    //    voxelSpacing[1] = 1;
    ImageTypeFloat3D::SizeType  size= img->GetLargestPossibleRegion().GetSize();
    //    ImageTypeFloat3D::IndexType PixelIndex;
    //    //float *imageptr= b->GetBufferPointer();
    //    long sizeptr = sizeof( float) * voxelSpacing[0]*voxelSpacing[1];
    //    float *imageptr =new float[sizeptr];
    //    NSMutableArray  *pixList        = [viewControlShow pixList];
    //    NSData *volumeData =[[NSMutableData alloc] autorelease];
    //    volumeData= [[self.volumeWindow viewerController]volumeData];
    ////    NSMutableArray *newFileArray = [NSMutableArray arrayWithArray:[[[self.volumeWindow viewerController] fileList] subarrayWithRange:NSMakeRange(0,size[2])]];
    ////    for (int j=0;j<size[2];j++){
    ////        DCMPix *PixTest= [[DCMPix alloc] initWithData:imageptr :32 :size[0] :size[1] :voxelSpacing[0] :voxelSpacing[1] :0 :0 :0];
    //   DCMPix *PixTest =[[viewControlShow pixList]objectAtIndex:1];
    //        float *fImageA=[PixTest fImage];
    //        for(int y=0;y<size[1];y++){
    //            for(int x=0;x<size[0];x++){
    //                PixelIndex[0]=x;
    //                PixelIndex[1]=y;
    //                PixelIndex[2]=j;
    //                fImageA[PixTest.pwidth*y+x]=img->GetPixel(PixelIndex);
    //            }
    //        }
    //        [pixList addObject: PixTest];
    //    [viewControlShow needsDisplayUpdate];
    ImageTypeFloat3D::IndexType PixelIndex;
    ImageTypeFloat2D::IndexType PixelIndex2D;
    for(int y=0;y<size[1];y++){
        for(int x=0;x<size[0];x++){
            PixelIndex[0]=x;
            PixelIndex[1]=y;
            PixelIndex[2]=j;
            PixelIndex2D[0]=x;
            PixelIndex2D[1]=y;
            imgOld->SetPixel(PixelIndex2D, img->GetPixel(PixelIndex));
        }
    }
    [viewControl1 needsDisplayUpdate];
}
-(ViewerController*)copyFloatImage3D:(ImageTypeFloat3D::Pointer) b
{
    double voxelSpacing[2];
    voxelSpacing[0] = 1;
    voxelSpacing[1] = 1;
    ImageTypeFloat3D::SizeType  size= b->GetLargestPossibleRegion().GetSize();
    ImageTypeFloat3D::IndexType PixelIndex;
    //float *imageptr= b->GetBufferPointer();
    long sizeptr = sizeof( float) * voxelSpacing[0]*voxelSpacing[1];
    float *imageptr =new float[sizeptr];
    NSMutableArray  *pixList        = [[[NSMutableArray alloc] initWithCapacity:0]autorelease];
    //    NSMutableData   *volumeData     = [[[NSMutableData alloc] initWithLength:0]autorelease];
    //    long mem            = size[0]*size[1]*size[2]* 4; // 4 Byte = 32 Bit Farbwert
    //    float *fVolumePtr   = new float(mem);
    //    if( fVolumePtr)
    //    {
    //        volumeData = [[NSMutableData alloc] initWithBytesNoCopy:fVolumePtr length:mem freeWhenDone:YES];
    //    }
    NSData *volumeData =[[NSMutableData alloc] autorelease];
    volumeData= [[self.volumeWindow viewerController]volumeData];
    NSMutableArray *newFileArray = [NSMutableArray arrayWithArray:[[[self.volumeWindow viewerController] fileList] subarrayWithRange:NSMakeRange(0,size[2])]];
    //    BOOL sliceIndex = [self slice];
    //    if (sliceIndex)
    //    {
    for (int j=0;j<size[2];j++){
        //DCMPix *PixTest=[[[self.volumeWindow viewerController] pixList] objectAtIndex:1];
        DCMPix *PixTest= [[DCMPix alloc] initWithData:imageptr :32 :size[0] :size[1] :voxelSpacing[0] :voxelSpacing[1] :0 :0 :0];
        float *fImageA=[PixTest fImage];
        for(int y=0;y<size[1];y++){
            for(int x=0;x<size[0];x++){
                PixelIndex[0]=x;
                PixelIndex[1]=y;
                PixelIndex[2]=j;
                fImageA[PixTest.pwidth*y+x]=b->GetPixel(PixelIndex);
            }
        }
        [pixList addObject: PixTest];
        
    }
    //    }
    //    else
    //    {
    //        for (int j=size[2]-1;j>=0;j--){
    //            //DCMPix *PixTest=[[[self.volumeWindow viewerController] pixList] objectAtIndex:1];
    //            DCMPix *PixTest= [[DCMPix alloc] initWithData:imageptr :32 :size[0] :size[1] :voxelSpacing[0] :voxelSpacing[1] :0 :0 :0];
    //            float *fImageA=[PixTest fImage];
    //            for(int y=0;y<size[1];y++){
    //                for(int x=0;x<size[0];x++){
    //                    PixelIndex[0]=x;
    //                    PixelIndex[1]=y;
    //                    PixelIndex[2]=j;
    //                    fImageA[PixTest.pwidth*y+x]=b->GetPixel(PixelIndex);
    //                }
    //            }
    //            [pixList addObject: PixTest];
    //
    //        }
    //    }
    ViewerController *view1=[[ViewerController alloc] newWindow:pixList :newFileArray :volumeData];
    return view1;
}

-(ViewerController*)copyIntImage3D:(ImageTypeInt3D::Pointer) b
{
    double voxelSpacing[2];
    voxelSpacing[0] = 1;
    voxelSpacing[1] = 1;
    ImageTypeInt3D::SizeType  size= b->GetLargestPossibleRegion().GetSize();
    ImageTypeInt3D::IndexType PixelIndex;
    //float *imageptr= b->GetBufferPointer();
    long sizeptr = sizeof( float) * voxelSpacing[0]*voxelSpacing[1];
    float *imageptr =new float[sizeptr];
    NSMutableArray  *pixList        = [[[NSMutableArray alloc] initWithCapacity:0]autorelease];
    //    NSMutableData   *volumeData     = [[[NSMutableData alloc] initWithLength:0]autorelease];
    //    long mem            = size[0]*size[1]*size[2]* 4; // 4 Byte = 32 Bit Farbwert
    //    float *fVolumePtr   = new float(mem);
    //    if( fVolumePtr)
    //    {
    //        volumeData = [[NSMutableData alloc] initWithBytesNoCopy:fVolumePtr length:mem freeWhenDone:YES];
    //    }
    NSData *volumeData =[[NSMutableData alloc] autorelease];
    volumeData= [[self.volumeWindow viewerController]volumeData];
    NSMutableArray *newFileArray = [NSMutableArray arrayWithArray:[[[self.volumeWindow viewerController] fileList] subarrayWithRange:NSMakeRange(0,size[2])]];
    for (int j=0;j<size[2];j++){
        //DCMPix *PixTest=[[[self.volumeWindow viewerController] pixList] objectAtIndex:1];
        DCMPix *PixTest= [[DCMPix alloc] initWithData:imageptr :32 :size[0] :size[1] :voxelSpacing[0] :voxelSpacing[1] :0 :0 :0];
        float *fImageA=[PixTest fImage];
        for(int y=0;y<size[1];y++){
            for(int x=0;x<size[0];x++){
                PixelIndex[0]=x;
                PixelIndex[1]=y;
                PixelIndex[2]=j;
                fImageA[PixTest.pwidth*y+x]=b->GetPixel(PixelIndex);
            }
        }
        [pixList addObject: PixTest];
        
    }
    ViewerController *view1=[[ViewerController alloc] newWindow:pixList :newFileArray :volumeData];
    return view1;
}
-(float)maxValuePixelFloat:(ImageTypeFloat3D::Pointer)b
{
    float a=0;
    ImageTypeFloat3D::RegionType region=b->GetLargestPossibleRegion();
    itk::ImageRegionConstIterator<ImageTypeFloat3D> it(b,region);//region est une région contenant le myocarde
    it.GoToBegin();//
    while (!it.IsAtEnd()) {
        ImageTypeFloat3D::IndexType index = it.GetIndex();
        float value=b->GetPixel(index);
        if (value>a) {
            a=value;
        }
        ++it;
    }
    return a;
}
-(int)maxValuePixelInt:(ImageTypeInt3D::Pointer)b
{
    int a=0;
    ImageTypeInt3D::RegionType region=b->GetLargestPossibleRegion();
    itk::ImageRegionConstIterator<ImageTypeInt3D> it(b,region);//region est une région contenant le myocarde
    it.GoToBegin();//
    while (!it.IsAtEnd()) {
        ImageTypeInt3D::IndexType index = it.GetIndex();
        int value=b->GetPixel(index);
        if (value>a) {
            a=value;
        }
        ++it;
    }
    return a;
}
///////////////////redistribution de la valeur des étiquette après élimination de la cavité
-(ImageTypeInt3D::Pointer) relabelingForVisualisationInt:(ImageTypeInt3D::Pointer)a
{
    ImageTypeInt3D::Pointer b = ImageTypeInt3D::New();
    ImageTypeInt3D::RegionType region;
    ImageTypeInt3D::IndexType start;
    ImageTypeInt3D::SizeType size=a->GetLargestPossibleRegion().GetSize();
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    b->SetRegions(region);
    b->Allocate();
    b->FillBuffer(0);
    itk::ImageRegionConstIterator<ImageTypeInt3D> it(a,a->GetRequestedRegion());
    it.GoToBegin();//
    float c=255/[self maxValuePixelInt:a];
    while (!it.IsAtEnd()) {
        ImageTypeInt3D::IndexType Index=it.GetIndex();
        float l=a->GetPixel(Index);
        b->SetPixel(Index, l*c) ;
        ++it;
    }
    return b;}
-(ImageTypeFloat3D::Pointer) relabelingForVisualisationFloat:(ImageTypeFloat3D::Pointer)a
{
    ImageTypeFloat3D::Pointer b = ImageTypeFloat3D::New();
    ImageTypeFloat3D::RegionType region;
    ImageTypeFloat3D::IndexType start;
    ImageTypeFloat3D::SizeType size=a->GetLargestPossibleRegion().GetSize();
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    b->SetRegions(region);
    b->Allocate();
    b->FillBuffer(0);
    itk::ImageRegionConstIterator<ImageTypeFloat3D> it(a,a->GetRequestedRegion());
    it.GoToBegin();//
    float c=255/[self maxValuePixelFloat:a];
    while (!it.IsAtEnd()) {
        ImageTypeFloat3D::IndexType Index=it.GetIndex();
        float l=a->GetPixel(Index);
        b->SetPixel(Index, l*c) ;
        ++it;
    }
    return b;
}
-(void)drawEndoEpicWithView:(ViewerController *)view atSlice:(int)slice
{
    NSMutableArray  *roiSeriesList = [[self.volumeWindow viewerController] roiList];
    NSMutableArray  *roiSeriesListNew = [view  roiList];
    if ([self slice]==TRUE){
        imageDepth=0;
        for (int numSeries=0;numSeries<[roiSeriesList count]; numSeries++) {
            [[self.volumeWindow viewerController] setImageIndex:numSeries];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                if (imageDepth==slice)
                {
                    NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
                    for (int numROI=0; numROI<[roiImageList count]; numROI++) {
                        if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
                            ROI *endoBaseROI = [roiImageList objectAtIndex:numROI]; ///à voir après pour
                            ROI *endoBaseROINew =[endoBaseROI copy];
                            NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:0];
                            [roiImageListNew addObject:endoBaseROINew];
                        }
                        if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Epicardium"]) {
                            ROI *epiBaseROI = [roiImageList objectAtIndex:numROI]; ///à voir après pour
                            ROI *epiBaseROINew =[epiBaseROI copy];
                            NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:0];
                            [roiImageListNew addObject:epiBaseROINew];
                        }
                        
                    }
                    break;
                }
                
                imageDepth=imageDepth+1;
            }
        }
    }
    else
    {
        imageDepth=0;
        for (int numSeries=[roiSeriesList count]-1;numSeries>=0; numSeries--) {
            [[self.volumeWindow viewerController] setImageIndex:[roiSeriesList count]-1-numSeries];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                if (imageDepth==slice)
                {
                    NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
                    for (int numROI=0; numROI<[roiImageList count]; numROI++) {
                        if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
                            ROI *endoBaseROI = [roiImageList objectAtIndex:numROI]; ///à voir après pour
                            ROI *endoBaseROINew =[endoBaseROI copy];
                            NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:0];
                            [roiImageListNew addObject:endoBaseROINew];
                        }
                        if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Epicardium"]) {
                            ROI *epiBaseROI = [roiImageList objectAtIndex:numROI]; ///à voir après pour
                            ROI *epiBaseROINew =[epiBaseROI copy];
                            NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:0];
                            [roiImageListNew addObject:epiBaseROINew];
                        }
                    }
                    break;
                }
                
                imageDepth=imageDepth+1;
            }
        }
    }
    NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:0];
    ROI *epiBaseROI;
    ROI *endoBaseROI;
    for (int numROI=0; numROI<[roiImageListNew count]; numROI++) {
        if ([[[roiImageListNew objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Epicardium"]) {
            epiBaseROI = [roiImageListNew objectAtIndex:numROI]; ///à voir après pour
        }
        if ([[[roiImageListNew objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
            endoBaseROI = [roiImageListNew objectAtIndex:numROI]; ///à voir après pour
        }
    }
    for (int numSeries=1;numSeries<[roiSeriesListNew count]; numSeries++) {
        roiImageListNew = [roiSeriesListNew objectAtIndex:numSeries];
        [roiImageListNew addObject:epiBaseROI];
        [roiImageListNew addObject:endoBaseROI];
    }
}

-(void)drawEndoEpicWithView:(ViewerController *)view
{
    imageDepth=0;
    NSMutableArray  *roiSeriesList = [[self.volumeWindow viewerController] roiList];
    BOOL sliceIndex = [self slice];
    if (sliceIndex==TRUE){
        for (int numSeries=0;numSeries<[roiSeriesList count]; numSeries++) {
            [[self.volumeWindow viewerController] setImageIndex:numSeries];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                // All rois contained in the current image
                NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
                for (int numROI=0; numROI<[roiImageList count]; numROI++) {
                    if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
                        ROI *endoBaseROI = [roiImageList objectAtIndex:numROI]; ///à voir après pour
                        ROI *endoBaseROINew =[endoBaseROI copy];
                        [endoBaseROINew setThickness:0.3];
                        NSMutableArray  *roiSeriesListNew = [view  roiList];
                        NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:imageDepth];
                        [roiImageListNew addObject:endoBaseROINew];
                    }
                    if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Epicardium"]) {
                        ROI *epiBaseROI = [roiImageList objectAtIndex:numROI]; ///à voir après pour
                        ROI *epiBaseROINew =[epiBaseROI copy];
                        [epiBaseROINew setThickness:0.3];
                        NSMutableArray  *roiSeriesListNew = [view  roiList];
                        NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:imageDepth];
                        [roiImageListNew addObject:epiBaseROINew];
                    }
                    
                }
                imageDepth=imageDepth+1;
            }
        }
    }
    else
    {
        for (int numSeries=[roiSeriesList count]-1;numSeries>=0; numSeries--) {
            [[self.volumeWindow viewerController] setImageIndex:[roiSeriesList count]-1-numSeries];
            // All rois contained in the current image
            NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                for (int numROI=0; numROI<[roiImageList count]; numROI++) {
                    if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
                        ROI *endoBaseROI = [roiImageList objectAtIndex:[roiImageList count]-numROI-1]; ///à voir après pour
                        ROI *endoBaseROINew =[endoBaseROI copy];
                        [endoBaseROINew setThickness:0.3];
                        NSMutableArray  *roiSeriesListNew = [view  roiList];
                        NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:imageDepth];
                        [roiImageListNew addObject:endoBaseROINew];
                    }
                    if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Epicardium"]) {
                        ROI *epiBaseROI = [roiImageList objectAtIndex:[roiImageList count]-numROI-1]; ///à voir après pour
                        ROI *epiBaseROINew =[epiBaseROI copy];
                        [epiBaseROINew setThickness:0.3];
                        NSMutableArray  *roiSeriesListNew = [view  roiList];
                        NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:imageDepth];
                        [roiImageListNew addObject:epiBaseROINew];
                    }
                    
                }
                imageDepth=imageDepth+1;
            }
        }
    }
}
-(void)drawEndoEpicWithViewPolar:(ViewerController *)view//cette méthode a quelques défauts
{
    float b=0;
    int c;
    NSMutableArray  *roiSeriesList = [[self.volumeWindow viewerController] roiList];
    if([self slice])
    {
        imageDepth=0;
        for (int numSeries=0;numSeries<[roiSeriesList count]; numSeries++) {
            [[self.volumeWindow viewerController] setImageIndex:numSeries];
            // All rois contained in the current image
            NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
            for (int numROI=0; numROI<[roiImageList count]; numROI++) {
                if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Epicardium"]) {
                    ROI *epiBaseROI = [roiImageList objectAtIndex:numROI]; ///à voir après pour
                    ROI *epiBaseROINew = [view newROI: tCPolygon ];
                    NSMutableArray *ptsNew = [epiBaseROINew points];
                    NSMutableArray  *pts = [epiBaseROI points];
                    for (int numPts = 0; numPts < [pts count]; numPts++)
                    {
                        MyPoint *point = [pts objectAtIndex:numPts];
                        float pixelIndex[3];
                        pixelIndex[0] = point.x;   // x position
                        pixelIndex[1] = point.y;   // y position
                        pixelIndex[2] = imageDepth;   // z position
                        pixelIndex[0] =(pixelIndex[0]-center.x);
                        pixelIndex[1] =(pixelIndex[1]-center.y);
                        NSPoint newPoint;
                        float theta=180*atanf(-pixelIndex[1]/pixelIndex[0])/M_PI;
                        if (pixelIndex[0]<0) {
                            theta=theta+180;
                        }
                        if (theta<0) {
                            theta=theta+360;
                        }
                        newPoint.x=theta;
                        float r=sqrt(pixelIndex[0]*pixelIndex[0]+pixelIndex[1]*pixelIndex[1]);
                        newPoint.y=r;
                        MyPoint *aNewPoint =[[MyPoint alloc]initWithPoint:newPoint];
                        [ptsNew addObject:aNewPoint];
                        if (newPoint.x>b) {
                            b=newPoint.x;
                            c=[ptsNew indexOfObject:aNewPoint];
                        }
                    }
                    for (int i=0; i<[ptsNew count]-1; i++) {
                        MyPoint *actualPoint = [ptsNew objectAtIndex:i];
                        MyPoint *nextPoint = [ptsNew objectAtIndex:i+1];
                        if (actualPoint.x == nextPoint.x) {
                            [ptsNew removeObjectAtIndex:i+1];
                        }
                    }
                    NSSortDescriptor  *nsSortDescriptor= [[NSSortDescriptor alloc] initWithKey:@"x" ascending:YES];
                    NSArray *sortDescriptors = [NSArray arrayWithObject:nsSortDescriptor];
                    NSArray *ptsNewNew = [ptsNew sortedArrayUsingDescriptors: sortDescriptors];
                    //                [ptsNew release];
                    ptsNew=[ptsNewNew mutableCopy];
                    for (int numPts = 0; numPts < [ptsNewNew count]; numPts++)
                    {
                        int l=[ptsNewNew count]-numPts-1;
                        [ptsNew addObject:[ptsNewNew objectAtIndex:l]];
                    }
                    ROI *epiBaseROIPolar = [view newROI: tCPolygon ];
                    NSMutableArray *ptsPolar=[[NSMutableArray alloc]initWithCapacity:[ptsNew count]];
                    ptsPolar = [epiBaseROIPolar points];
                    
                    for (int numPts = 0; numPts < [ptsNew count]; numPts++)
                    {
                        [[epiBaseROIPolar points] addObject:[ptsNew objectAtIndex:numPts]];
                    }
                    
                    //                [ptsNewNew release];
                    //                //[ptsNew release];
                    //                //[ptsNew release];
                    //                [pts release];
                    //                //[ptsNew dealloc];
                    //                [ptsNewNew dealloc];
                    NSMutableArray  *roiSeriesListNew = [view  roiList];
                    NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:imageDepth];
                    //[[endoBaseROINew points]setValue:ptsNew];
                    [roiImageListNew addObject:epiBaseROIPolar];
                    [epiBaseROIPolar setColor:(RGBColor){0,255*255,0}];
                    [epiBaseROIPolar setOpacity:0.3];
                }
            }
            b=0;
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                imageDepth=imageDepth+1;
            }
        }
        imageDepth=0;
        for (int numSeries=0;numSeries<[roiSeriesList count]; numSeries++) {
            [[self.volumeWindow viewerController] setImageIndex:numSeries];
            // All rois contained in the current image
            NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
            for (int numROI=0; numROI<[roiImageList count]; numROI++) {
                if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
                    ROI *endoBaseROI = [roiImageList objectAtIndex:numROI]; ///à voir après pour
                    ROI *endoBaseROINew = [view newROI: tCPolygon ];
                    NSMutableArray *ptsNew = [endoBaseROINew points];
                    NSMutableArray  *pts = [endoBaseROI points];
                    for (int numPts = 0; numPts < [pts count]; numPts++)
                    {
                        MyPoint *point = [pts objectAtIndex:numPts];
                        float pixelIndex[3];
                        pixelIndex[0] = point.x;   // x position
                        pixelIndex[1] = point.y;   // y position
                        pixelIndex[2] = imageDepth;   // z position
                        pixelIndex[0] =(pixelIndex[0]-center.x);
                        pixelIndex[1] =(pixelIndex[1]-center.y);
                        NSPoint newPoint;
                        float theta=180*atanf(-pixelIndex[1]/pixelIndex[0])/M_PI;
                        if (pixelIndex[0]<0) {
                            theta=theta+180;
                        }
                        if (theta<0) {
                            theta=theta+360;
                        }
                        newPoint.x=theta;
                        float r=sqrt(pixelIndex[0]*pixelIndex[0]+pixelIndex[1]*pixelIndex[1]);
                        newPoint.y=r;
                        MyPoint *aNewPoint =[[MyPoint alloc]initWithPoint:newPoint];
                        [ptsNew addObject:aNewPoint];
                        if (newPoint.x>b) {
                            b=newPoint.x;
                            c=[ptsNew indexOfObject:aNewPoint];
                        }
                    }
                    for (int i=0; i<[ptsNew count]-1; i++) {
                        MyPoint *actualPoint = [ptsNew objectAtIndex:i];
                        MyPoint *nextPoint = [ptsNew objectAtIndex:i+1];
                        if (actualPoint.x == nextPoint.x) {
                            [ptsNew removeObjectAtIndex:i+1];
                        }
                    }
                    NSSortDescriptor  *nsSortDescriptor= [[NSSortDescriptor alloc] initWithKey:@"x" ascending:YES];
                    NSArray *sortDescriptors = [NSArray arrayWithObject:nsSortDescriptor];
                    NSArray *ptsNewNew = [ptsNew sortedArrayUsingDescriptors: sortDescriptors];
                    //                [ptsNew release];
                    ptsNew=[ptsNewNew mutableCopy];
                    for (int numPts = 0; numPts < [ptsNewNew count]; numPts++)
                    {
                        int l=[ptsNewNew count]-numPts-1;
                        [ptsNew addObject:[ptsNewNew objectAtIndex:l]];
                    }
                    ROI *endoBaseROIPolar = [view newROI: tCPolygon ];
                    NSMutableArray *ptsPolar=[[NSMutableArray alloc]initWithCapacity:[ptsNew count]];
                    ptsPolar = [endoBaseROIPolar points];
                    
                    for (int numPts = 0; numPts < [ptsNew count]; numPts++)
                    {
                        [[endoBaseROIPolar points] addObject:[ptsNew objectAtIndex:numPts]];
                    }
                    
                    //                [ptsNewNew release];
                    //                //[ptsNew release];
                    //                //[ptsNew release];
                    //                [pts release];
                    //                //[ptsNew dealloc];
                    //                [ptsNewNew dealloc];
                    NSMutableArray  *roiSeriesListNew = [view  roiList];
                    NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:imageDepth];
                    //[[endoBaseROINew points]setValue:ptsNew];
                    [roiImageListNew addObject:endoBaseROIPolar];
                    [endoBaseROIPolar setColor:(RGBColor){255*255,0,0}];
                    [endoBaseROIPolar setOpacity:0.3];
                }
            }
            b=0;
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                imageDepth=imageDepth+1;
            }
        }
    }
    else
    {
        imageDepth=0;
        for (int numSeries=[roiSeriesList count]-1;numSeries>=0;numSeries--) {
            [[self.volumeWindow viewerController] setImageIndex:[roiSeriesList count]-1-numSeries];
            // All rois contained in the current image
            NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
            for (int numROI=0; numROI<[roiImageList count]; numROI++) {
                if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Epicardium"]) {
                    ROI *epiBaseROI = [roiImageList objectAtIndex:numROI]; ///à voir après pour
                    ROI *epiBaseROINew = [view newROI: tCPolygon ];
                    NSMutableArray *ptsNew = [epiBaseROINew points];
                    NSMutableArray  *pts = [epiBaseROI points];
                    for (int numPts = 0; numPts < [pts count]; numPts++)
                    {
                        MyPoint *point = [pts objectAtIndex:numPts];
                        float pixelIndex[3];
                        pixelIndex[0] = point.x;   // x position
                        pixelIndex[1] = point.y;   // y position
                        pixelIndex[2] = imageDepth;   // z position
                        pixelIndex[0] =(pixelIndex[0]-center.x);
                        pixelIndex[1] =(pixelIndex[1]-center.y);
                        NSPoint newPoint;
                        float theta=180*atanf(-pixelIndex[1]/pixelIndex[0])/M_PI;
                        if (pixelIndex[0]<0) {
                            theta=theta+180;
                        }
                        if (theta<0) {
                            theta=theta+360;
                        }
                        newPoint.x=theta;
                        float r=sqrt(pixelIndex[0]*pixelIndex[0]+pixelIndex[1]*pixelIndex[1]);
                        newPoint.y=r;
                        MyPoint *aNewPoint =[[MyPoint alloc]initWithPoint:newPoint];
                        [ptsNew addObject:aNewPoint];
                        if (newPoint.x>b) {
                            b=newPoint.x;
                            c=[ptsNew indexOfObject:aNewPoint];
                        }
                    }
                    for (int i=0; i<[ptsNew count]-1; i++) {
                        MyPoint *actualPoint = [ptsNew objectAtIndex:i];
                        MyPoint *nextPoint = [ptsNew objectAtIndex:i+1];
                        if (actualPoint.x == nextPoint.x) {
                            [ptsNew removeObjectAtIndex:i+1];
                        }
                    }
                    NSSortDescriptor  *nsSortDescriptor= [[NSSortDescriptor alloc] initWithKey:@"x" ascending:YES];
                    NSArray *sortDescriptors = [NSArray arrayWithObject:nsSortDescriptor];
                    NSArray *ptsNewNew = [ptsNew sortedArrayUsingDescriptors: sortDescriptors];
                    //                [ptsNew release];
                    ptsNew=[ptsNewNew mutableCopy];
                    for (int numPts = 0; numPts < [ptsNewNew count]; numPts++)
                    {
                        int l=[ptsNewNew count]-numPts-1;
                        [ptsNew addObject:[ptsNewNew objectAtIndex:l]];
                    }
                    ROI *epiBaseROIPolar = [view newROI: tCPolygon ];
                    NSMutableArray *ptsPolar=[[NSMutableArray alloc]initWithCapacity:[ptsNew count]];
                    ptsPolar = [epiBaseROIPolar points];
                    
                    for (int numPts = 0; numPts < [ptsNew count]; numPts++)
                    {
                        [[epiBaseROIPolar points] addObject:[ptsNew objectAtIndex:numPts]];
                    }
                    
                    //                [ptsNewNew release];
                    //                //[ptsNew release];
                    //                //[ptsNew release];
                    //                [pts release];
                    //                //[ptsNew dealloc];
                    //                [ptsNewNew dealloc];
                    NSMutableArray  *roiSeriesListNew = [view  roiList];
                    NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:imageDepth];
                    //[[endoBaseROINew points]setValue:ptsNew];
                    [roiImageListNew addObject:epiBaseROIPolar];
                    [epiBaseROIPolar setColor:(RGBColor){0,255*255,0}];
                    [epiBaseROIPolar setOpacity:0.3];
                }
            }
            b=0;
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                imageDepth=imageDepth+1;
            }
        }
        imageDepth=0;
        for (int numSeries=[roiSeriesList count]-1;numSeries>=0;numSeries--) {
            [[self.volumeWindow viewerController] setImageIndex:[roiSeriesList count]-1-numSeries];
            // All rois contained in the current image
            NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
            for (int numROI=0; numROI<[roiImageList count]; numROI++) {
                if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
                    ROI *endoBaseROI = [roiImageList objectAtIndex:numROI]; ///à voir après pour
                    ROI *endoBaseROINew = [view newROI: tCPolygon ];
                    NSMutableArray *ptsNew = [endoBaseROINew points];
                    NSMutableArray  *pts = [endoBaseROI points];
                    for (int numPts = 0; numPts < [pts count]; numPts++)
                    {
                        MyPoint *point = [pts objectAtIndex:numPts];
                        float pixelIndex[3];
                        pixelIndex[0] = point.x;   // x position
                        pixelIndex[1] = point.y;   // y position
                        pixelIndex[2] = imageDepth;   // z position
                        pixelIndex[0] =(pixelIndex[0]-center.x);
                        pixelIndex[1] =(pixelIndex[1]-center.y);
                        NSPoint newPoint;
                        float theta=180*atanf(-pixelIndex[1]/pixelIndex[0])/M_PI;
                        if (pixelIndex[0]<0) {
                            theta=theta+180;
                        }
                        if (theta<0) {
                            theta=theta+360;
                        }
                        newPoint.x=theta;
                        float r=sqrt(pixelIndex[0]*pixelIndex[0]+pixelIndex[1]*pixelIndex[1]);
                        newPoint.y=r;
                        MyPoint *aNewPoint =[[MyPoint alloc]initWithPoint:newPoint];
                        [ptsNew addObject:aNewPoint];
                        if (newPoint.x>b) {
                            b=newPoint.x;
                            c=[ptsNew indexOfObject:aNewPoint];
                        }
                    }
                    for (int i=0; i<[ptsNew count]-1; i++) {
                        MyPoint *actualPoint = [ptsNew objectAtIndex:i];
                        MyPoint *nextPoint = [ptsNew objectAtIndex:i+1];
                        if (actualPoint.x == nextPoint.x) {
                            [ptsNew removeObjectAtIndex:i+1];
                        }
                    }
                    NSSortDescriptor  *nsSortDescriptor= [[NSSortDescriptor alloc] initWithKey:@"x" ascending:YES];
                    NSArray *sortDescriptors = [NSArray arrayWithObject:nsSortDescriptor];
                    NSArray *ptsNewNew = [ptsNew sortedArrayUsingDescriptors: sortDescriptors];
                    //                [ptsNew release];
                    ptsNew=[ptsNewNew mutableCopy];
                    for (int numPts = 0; numPts < [ptsNewNew count]; numPts++)
                    {
                        int l=[ptsNewNew count]-numPts-1;
                        [ptsNew addObject:[ptsNewNew objectAtIndex:l]];
                    }
                    ROI *endoBaseROIPolar = [view newROI: tCPolygon ];
                    NSMutableArray *ptsPolar=[[NSMutableArray alloc]initWithCapacity:[ptsNew count]];
                    ptsPolar = [endoBaseROIPolar points];
                    
                    for (int numPts = 0; numPts < [ptsNew count]; numPts++)
                    {
                        [[endoBaseROIPolar points] addObject:[ptsNew objectAtIndex:numPts]];
                    }
                    
                    //                [ptsNewNew release];
                    //                //[ptsNew release];
                    //                //[ptsNew release];
                    //                [pts release];
                    //                //[ptsNew dealloc];
                    //                [ptsNewNew dealloc];
                    NSMutableArray  *roiSeriesListNew = [view  roiList];
                    NSMutableArray  *roiImageListNew = [roiSeriesListNew objectAtIndex:imageDepth];
                    //[[endoBaseROINew points]setValue:ptsNew];
                    [roiImageListNew addObject:endoBaseROIPolar];
                    [endoBaseROIPolar setColor:(RGBColor){255*255,0,0}];
                    [endoBaseROIPolar setOpacity:0.3];
                }
            }
            b=0;
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                imageDepth=imageDepth+1;
            }
        }
    }
}
#endif
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////

- (id)initWithVolumeWindow:(OSIVolumeWindow *)volumeWindow
{
    self.volumeWindow = volumeWindow;
    image = ImageTypeFloat3D::New();
    myocardium = ImageTypeInt3D::New();
    myocardiumPolar = ImageTypeFloat3D::New();
    label = ImageTypeFloat3D::New();
    labelCart = ImageTypeFloat3D::New();
    noReflowCart = ImageTypeFloat3D::New();
    viewControl=[self.volumeWindow viewerController];
    return self;
}

// current image in ITK space :
- (ImageTypeFloat2D::Pointer)WrapImageFloat2D
{
    long SliceIndex = [[viewControl imageView]curImage];
    
    ImageTypeFloat2D::Pointer wrapImage;
    ImportFilterTypeFloat2D::Pointer importFilter = ImportFilterTypeFloat2D::New();
    ImportFilterTypeFloat2D::SizeType size;
    ImportFilterTypeFloat2D::IndexType start;
    ImportFilterTypeFloat2D::RegionType region;
    
    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    
    long bufferSize = size[0] * size[1];
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    
    double voxelSpacing[3];
    double origin[3];
    origin[0] = [firstPix originX];
    origin[1] = [firstPix originY];
    voxelSpacing[0] = [firstPix pixelSpacingX];
    voxelSpacing[1] = [firstPix pixelSpacingY];
    
    importFilter->SetRegion(region);
    importFilter->SetSpacing(voxelSpacing);
    importFilter->SetImportPointer([viewControl volumePtr]+bufferSize*SliceIndex , bufferSize, false);// do not overwrite original data
    
    wrapImage = importFilter->GetOutput();
    wrapImage->Update();
    return wrapImage;
}
// image 3D in polar coordinates
- (void)imagePolar
{
    // initialize myocardium mask :
    myocardium = ImageTypeInt3D::New();
    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    //    NSUInteger slices = [[viewControl pixList] count];
    ImageTypeInt3D::SizeType size;
    ImageTypeInt3D::IndexType start;
    ImageTypeInt3D::RegionType region;
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    slicesNumber=0;
    NSMutableArray  *roiSeriesList  = [viewControl roiList];
    for (int j=0; j<[roiSeriesList count]; j++) {
        [viewControl setImageIndex:j];
        if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
        {
            slicesNumber=slicesNumber+1;
        }
    }
    size[2]=slicesNumber;
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    myocardium->SetRegions(region);
    myocardium->Allocate();
    myocardium->FillBuffer(0);
    typedef itk::JoinSeriesImageFilter<ImageTypeFloat2D, ImageTypeFloat3D> JoinSeriesImageFilterType;
    JoinSeriesImageFilterType::Pointer joinSeriesImageFilter1 = JoinSeriesImageFilterType::New();
    joinSeriesImageFilter1->SetOrigin(0);
    joinSeriesImageFilter1->SetSpacing(1);
    JoinSeriesImageFilterType::Pointer joinSeriesImageFilter2 = JoinSeriesImageFilterType::New();
    joinSeriesImageFilter2->SetOrigin(0);
    joinSeriesImageFilter2->SetSpacing(1);
    JoinSeriesImageFilterType::Pointer joinSeriesImageFilter3 = JoinSeriesImageFilterType::New();
    joinSeriesImageFilter3->SetOrigin(0);
    joinSeriesImageFilter3->SetSpacing(1);
    // center of myocardium and epicardium ray
    [self centerRay];
    int curIndex = [[viewControl imageView]curImage];
    BOOL sliceIndex = [self slice];
    imageDepth=0;
    std::vector<double> meanVector1,meanVector2,stdVector1,stdVector2;
    // if image is defined anterior -> posterior or right -> left
    if (sliceIndex) {
        for (int j=0; j<[roiSeriesList count]; j++) {
            [viewControl setImageIndex:j];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                ImageTypeFloat2D::Pointer imagePolar2D = [self cartesian2polar]; // image in polar coordinates
                joinSeriesImageFilter1->PushBackInput(imagePolar2D);
                ImageTypeFloat2D::Pointer myocardium2D = [self initParam];
                ImageTypeFloat2D::Pointer myocardiumPolar2D = [self cartesian2polarMyo:myocardium2D];// myocardium mask in polar coordinates
                joinSeriesImageFilter2->PushBackInput(myocardiumPolar2D);
                
                typedef itk::BinaryThresholdImageFilter<ImageTypeFloat2D,ImageTypeFloat2D> BinaryThresholdImageFilterType;
                BinaryThresholdImageFilterType::Pointer binaryThresholdImageFilter = BinaryThresholdImageFilterType::New();
                binaryThresholdImageFilter->SetInput(imagePolar2D);
                typedef itk::LabelStatisticsImageFilter <ImageTypeFloat2D,ImageTypeInt2D > LabelStatisticsImageFilter;
                typedef itk::CastImageFilter<ImageTypeFloat2D, ImageTypeInt2D> CastImageFilterType;
                LabelStatisticsImageFilter::Pointer statFilter= LabelStatisticsImageFilter::New();
                CastImageFilterType::Pointer castImageFilter = CastImageFilterType::New();
                castImageFilter->SetInput(myocardiumPolar2D);
                castImageFilter->Update();
                statFilter->SetLabelInput(castImageFilter->GetOutput());
                statFilter->SetInput(imagePolar2D);
                statFilter->Update();
                float max=statFilter->GetMaximum(1);
                binaryThresholdImageFilter->SetLowerThreshold(0);
                binaryThresholdImageFilter->SetUpperThreshold(initialThreshold*max);
                binaryThresholdImageFilter->SetInsideValue(0);
                binaryThresholdImageFilter->SetOutsideValue(1);
                binaryThresholdImageFilter->Update();
                joinSeriesImageFilter3->PushBackInput(binaryThresholdImageFilter->GetOutput());
                imageDepth=imageDepth+1;
            }
        }
        [viewControl setImageIndex:curIndex];
    }
    else
    {
        for (int j=[roiSeriesList count]-1; j>=0; j--)
        {
            [viewControl setImageIndex:[roiSeriesList count]-1-j];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                ImageTypeFloat2D::Pointer imagePolar2D = [self cartesian2polar]; // image in polar coordinates
                joinSeriesImageFilter1->PushBackInput(imagePolar2D);
                ImageTypeFloat2D::Pointer myocardium2D = [self initParam];
                ImageTypeFloat2D::Pointer myocardiumPolar2D = [self cartesian2polarMyo:myocardium2D];// myocardium mask in polar coordinates
                joinSeriesImageFilter2->PushBackInput(myocardiumPolar2D);
                
                typedef itk::BinaryThresholdImageFilter<ImageTypeFloat2D,ImageTypeFloat2D> BinaryThresholdImageFilterType;
                BinaryThresholdImageFilterType::Pointer binaryThresholdImageFilter = BinaryThresholdImageFilterType::New();
                binaryThresholdImageFilter->SetInput(imagePolar2D);
                typedef itk::LabelStatisticsImageFilter <ImageTypeFloat2D,ImageTypeInt2D > LabelStatisticsImageFilter;
                typedef itk::CastImageFilter<ImageTypeFloat2D, ImageTypeInt2D> CastImageFilterType;
                LabelStatisticsImageFilter::Pointer statFilter= LabelStatisticsImageFilter::New();
                CastImageFilterType::Pointer castImageFilter = CastImageFilterType::New();
                castImageFilter->SetInput(myocardiumPolar2D);
                castImageFilter->Update();
                statFilter->SetLabelInput(castImageFilter->GetOutput());
                statFilter->SetInput(imagePolar2D);
                statFilter->Update();
                float max=statFilter->GetMaximum(1);
                binaryThresholdImageFilter->SetLowerThreshold(0);
                binaryThresholdImageFilter->SetUpperThreshold(initialThreshold*max);
                binaryThresholdImageFilter->SetInsideValue(0);
                binaryThresholdImageFilter->SetOutsideValue(1);
                binaryThresholdImageFilter->Update();
                joinSeriesImageFilter3->PushBackInput(binaryThresholdImageFilter->GetOutput());
                imageDepth=imageDepth+1;
            }
        }
        [viewControl setImageIndex:(int)[roiSeriesList count]-curIndex-1];
    }
    joinSeriesImageFilter1->Update();
    joinSeriesImageFilter2->Update();
    joinSeriesImageFilter3->Update();
    image = joinSeriesImageFilter1->GetOutput();
    myocardiumPolar = joinSeriesImageFilter2->GetOutput();
    label=joinSeriesImageFilter3->GetOutput();
    numberWhitePixel.push_back(0);
    time=0;
    itk::ImageRegionConstIterator<ImageTypeFloat3D> it1(label,label->GetLargestPossibleRegion());
    it1.GoToBegin();
    while (!it1.IsAtEnd()) {
        ImageTypeFloat3D::IndexType index=it1.GetIndex();
        if (label->GetPixel(index)>0) {
            numberWhitePixel.at(0)++;
        }
        ++it1;
    }
    typedef itk::LabelStatisticsImageFilter <ImageTypeFloat3D,ImageTypeInt3D > LabelStatisticsImageFilter;
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> CastImageFilterType;
    typedef itk::MultiplyImageFilter<ImageTypeFloat3D,ImageTypeFloat3D> multiplyType;
    multiplyType::Pointer multiplyHigh = multiplyType::New();
    multiplyHigh->SetInput1(label);
    multiplyHigh->SetInput2(myocardiumPolar);
    multiplyHigh->Update();
    CastImageFilterType::Pointer castImageFilterHigh = CastImageFilterType::New();
    castImageFilterHigh->SetInput(label);
    castImageFilterHigh->Update();
    LabelStatisticsImageFilter::Pointer statFilterHigh= LabelStatisticsImageFilter::New();
    statFilterHigh->SetLabelInput(castImageFilterHigh->GetOutput());
    statFilterHigh->SetInput(image);
    statFilterHigh->Update();
    mean2=statFilterHigh->GetMean(1);
    std2=statFilterHigh->GetSigma(1);
    mean1=statFilterHigh->GetMean(0);
    std1=statFilterHigh->GetSigma(0);
    
}

// image in cartesian coordinates to polar coordinates
- (ImageTypeFloat2D::Pointer)cartesian2polar
{
    ImageTypeFloat2D::Pointer image2D = [self WrapImageFloat2D];
    ImageTypeFloat2D::Pointer imagePolar2D = ImageTypeFloat2D::New();
    ImageTypeFloat2D::SizeType size = image2D->GetLargestPossibleRegion().GetSize();
    
    //new image : we work only on the myocardium :
    ImageTypeFloat2D::SizeType newSize;
    ImageTypeFloat2D::IndexType start;
    ImageTypeFloat2D::RegionType region;
    newSize[0] = 360;
    newSize[1] = ray;
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(newSize);
    imagePolar2D->SetRegions(region);
    imagePolar2D->Allocate();
    imagePolar2D->FillBuffer(0);
    
    itk::ImageRegionConstIterator<ImageTypeFloat2D> it(imagePolar2D,region);
    it.GoToBegin();
    while (!it.IsAtEnd()) {
        ImageTypeFloat2D::IndexType index = it.GetIndex();
        double thetaRad = M_PI*index[0]/180;
        double x = index[1]*cos(thetaRad) + center.x;
        double y = -index[1]*sin(thetaRad) +center.y;
        double v = abs(floor(x)-x);
        double u = abs(floor(y)-y);
        if (x>=0 && y>=0 && x<size[0] && y<size[1]) {
            // interpolation
            ImageTypeFloat2D::IndexType indexCart = it.GetIndex();
            indexCart[0] = floor(x);
            indexCart[1] = floor(y)+1;
            double A = image2D->GetPixel(indexCart);
            indexCart[0] = floor(x)+1;
            indexCart[1] = floor(y)+1;
            double B = image2D->GetPixel(indexCart);
            indexCart[0] = floor(x)+1;
            indexCart[1] = floor(y);
            double C = image2D->GetPixel(indexCart);
            indexCart[0] = floor(x);
            indexCart[1] = floor(y);
            double D = image2D->GetPixel(indexCart);
            imagePolar2D->SetPixel(index, u*(1-v)*A + u*v*B + v*(1-u)*C + (1-u)*(1-v)*D);
        }
        ++it;
    }
    return imagePolar2D;
}

// myocardium mask in cartesian coordinates to polar coordinates
- (ImageTypeFloat2D::Pointer)cartesian2polarMyo:(ImageTypeFloat2D::Pointer)img
{
    ImageTypeFloat2D::Pointer imagePolar2D = ImageTypeFloat2D::New();
    ImageTypeFloat2D::SizeType size = img->GetLargestPossibleRegion().GetSize();
    
    ImageTypeFloat2D::SizeType newSize;
    ImageTypeFloat2D::IndexType start;
    ImageTypeFloat2D::RegionType region;
    newSize[0] = 360;
    newSize[1] = ray;
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(newSize);
    imagePolar2D->SetRegions(region);
    imagePolar2D->Allocate();
    imagePolar2D->FillBuffer(0);
    
    itk::ImageRegionConstIterator<ImageTypeFloat2D> it(imagePolar2D,region);
    it.GoToBegin();
    while (!it.IsAtEnd()) {
        ImageTypeFloat2D::IndexType index = it.GetIndex();
        double thetaRad = M_PI*index[0]/180;
        double x = index[1]*cos(thetaRad) + center.x;
        double y = -index[1]*sin(thetaRad) +center.y;
        double v = abs(floor(x)-x);
        double u = abs(floor(y)-y);
        // interpolation
        if (x>=0 && y>=0 && x<size[0] && y<size[1]) {
            ImageTypeFloat2D::IndexType indexCart = it.GetIndex();
            indexCart[0] = floor(x);
            indexCart[1] = floor(y)+1;
            double A = img->GetPixel(indexCart);
            indexCart[0] = floor(x)+1;
            indexCart[1] = floor(y)+1;
            double B = img->GetPixel(indexCart);
            indexCart[0] = floor(x)+1;
            indexCart[1] = floor(y);
            double C = img->GetPixel(indexCart);
            indexCart[0] = floor(x);
            indexCart[1] = floor(y);
            double D = img->GetPixel(indexCart);
            imagePolar2D->SetPixel(index, u*(1-v)*A + u*v*B + v*(1-u)*C + (1-u)*(1-v)*D);
        }
        ++it;
    }
    
    typedef itk::BinaryThresholdImageFilter <ImageTypeFloat2D, ImageTypeFloat2D> BinaryThresholdImageFilterType;
    BinaryThresholdImageFilterType::Pointer thresholdFilter = BinaryThresholdImageFilterType::New();
    thresholdFilter->SetInput(imagePolar2D);
    thresholdFilter->SetLowerThreshold(0);
    thresholdFilter->SetUpperThreshold(0.5);
    thresholdFilter->SetInsideValue(0);
    thresholdFilter->SetOutsideValue(1);
    thresholdFilter->Update();
    
    return thresholdFilter->GetOutput();
}

// compute the center of mass of Epicardium and endocardium
- (void)centerRay
{
    DCMView *view = [viewControl imageView];
    DCMPix *pix = [view curDCM];
    double pixelSpacingX = [pix pixelSpacingX];
    
    std::vector<double> x;
    std::vector<double> y;
    std::vector<double> r;
    NSArray* ROIsOutside = [[self.volumeWindow ROIManager]ROIsWithName:@"CMRSegTools: Epicardium"];
    NSArray* ROIsInside = [[self.volumeWindow ROIManager]ROIsWithName:@"CMRSegTools: Endocardium"];
    for (OSIROI* outsideROI in ROIsOutside) {
        ROI* outsideBaseROI = [[outsideROI osiriXROIs]anyObject];
        NSPoint centerOutside = [outsideBaseROI centroid];
        x.push_back(centerOutside.x);
        y.push_back(centerOutside.y);
        
        double outsideAreaCm = [outsideBaseROI roiArea];
        double outsideRadiusCm = sqrt(outsideAreaCm/M_PI);
        double outsideRadiusMm = outsideRadiusCm * 10.0;
        r.push_back(outsideRadiusMm/pixelSpacingX);
    }
    for (OSIROI* insideROI in ROIsInside) {
        ROI* insideBaseROI = [[insideROI osiriXROIs]anyObject];
        NSPoint centerInside = [insideBaseROI centroid];
        x.push_back(centerInside.x);
        y.push_back(centerInside.y);
    }
    ray = floor(*std::max_element(r.begin(), r.end()) + 10);
    center.x = std::accumulate(x.begin(), x.end(), 0)/x.size();
    center.y = std::accumulate(y.begin(), y.end(), 0)/y.size();
}

// compute myocardium mask in cartesian coordinates and initial parameters.
- (ImageTypeFloat2D::Pointer)initParam
{
    ImageTypeFloat2D::Pointer myocardium2D = ImageTypeFloat2D::New();
    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    ImageTypeFloat2D::SizeType size;
    ImageTypeFloat2D::IndexType start;
    ImageTypeFloat2D::RegionType region;
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    myocardium2D->SetRegions(region);
    myocardium2D->Allocate();
    myocardium2D->FillBuffer(0);
    
    OSIROI* outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];
    OSIROI* insideROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
    // From Amine's dev version. Remove?
    // OSIROI* outsideROI = [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"];
    // OSIROI* insideROI = [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"];
    
    if (outsideROI && insideROI) {
        
        OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
        OSIROIMask *outsideMask = [outsideROI ROIMaskForFloatVolumeData:floatVolumeData];
        OSIROIMask *insideMask = [insideROI ROIMaskForFloatVolumeData:floatVolumeData];
        OSIROIMask *myocardiumMask = [outsideMask ROIMaskBySubtractingMask:insideMask];
        NSArray *arrayMaskRuns = [myocardiumMask maskRuns];
        myoSize.push_back(0);
        for (NSValue *value in arrayMaskRuns) {
            OSIROIMaskRun run;
            [value getValue:&run];
            NSRange range =  run.widthRange;
            for (int i = 0; i<range.length; i++) {
                ImageTypeFloat2D::IndexType pixelIndex;
                pixelIndex[0] = range.location+i;   // x position
                pixelIndex[1] = run.heightIndex;    // y position
                myocardium2D->SetPixel(pixelIndex, 1);
                myoSize.at(imageDepth)=myoSize.at(imageDepth)+1;
                ImageTypeFloat3D::IndexType pixelIndex3D;
                pixelIndex3D[0] = range.location+i;   // x position
                pixelIndex3D[1] = run.heightIndex;    // y position
                pixelIndex3D[2] = imageDepth;     // z position
                myocardium->SetPixel(pixelIndex3D, 1);
            }
            
        }
    }
    return myocardium2D;
}

// get the pixels that surround the infarct label
- (std::vector<LabelGeometryImageFilterType::LabelIndexType>)regionGrowing
{
    typedef itk::BinaryContourImageFilter<ImageTypeFloat3D, ImageTypeFloat3D> BinaryContourImageFilterType;
    BinaryContourImageFilterType::Pointer binaryContourImageFilter = BinaryContourImageFilterType::New();
    binaryContourImageFilter->SetInput(label);
    binaryContourImageFilter->SetForegroundValue(0);
    binaryContourImageFilter->SetBackgroundValue(1);
    binaryContourImageFilter->Update();
    
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> CastImageFilterType;
    CastImageFilterType::Pointer castImageFilter = CastImageFilterType::New();
    castImageFilter->SetInput(binaryContourImageFilter->GetOutput());
    castImageFilter->Update();
    
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
    labelGeometryImageFilter->SetInput( castImageFilter->GetOutput() );
    labelGeometryImageFilter->CalculatePixelIndicesOn();
    labelGeometryImageFilter->Update();
    LabelGeometryImageFilterType::LabelsType allLabels = labelGeometryImageFilter->GetLabels();
    LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt;
    
    std::vector<LabelGeometryImageFilterType::LabelIndexType> vect;
    for( allLabelsIt = allLabels.begin(); allLabelsIt != allLabels.end(); allLabelsIt++ )
    {
        LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
        if (labelValue==0) {
            vect = labelGeometryImageFilter->GetPixelIndices(labelValue);
        }
    }
    return vect;
}

// MAP algorithm
- (void)MAP
{
    std::vector<double> sum_U_MAP;
    for (int i=0; i<itMAP; i++) {
        ImageTypeFloat3D::Pointer copyLabel = label;
        time++;
        numberWhitePixel.push_back(0);
        if (labelChanged== true)
        {
            contour = [self regionGrowing];
        }
        else if (i>0)
        {
            break;
        }
        labelChanged=false;
        sum_U_MAP.push_back(0);
        // for all bordering pixels
        for (int j=0; j<contour.size(); j++) {
            // likelihood energy for label 0 and label 1
            double y0 = image->GetPixel(contour.at(j)) - mean1;
            double y1 = image->GetPixel(contour.at(j)) - mean2;
            double U1_0 = y0*y0 / (2*std1*std1);
            double U1_1 = y1*y1 / (2*std2*std2);
            U1_0 = U1_0 + log(std1);
            U1_1 = U1_1 + log(std2);
            
            // prior energy for label 0 and label 1
            double U2_0 = [self clique:0 :contour.at(j)];
            double U2_1 = [self clique:1 :contour.at(j)];
            
            // sum of likelihood and prior energy for label 0 and label 1
            double U_0 = U1_0 + U2_0;
            double U_1 = U1_1 + U2_1;
            double x,val;
            if (U_0<U_1) {
                x = 0;
                val = U_0;
            }
            else {
                x = 1;
                val = U_1;
                labelChanged = true;
                numberWhitePixel.at(time)++;
            }
            sum_U_MAP.at(i) = sum_U_MAP.at(i) + val;
            copyLabel->SetPixel(contour.at(j), x);
        }
        // if it converges, stop the loop
        U = sum_U_MAP.at(i);
        
#ifdef DEBUG_HMRF_DEV_1
// Alexandra's instructions. Keep?
        fputs("   ",fichier1);
        snprintf(mychar,sizeof(mychar),"%d ",i) ;
        fputs(mychar, fichier1);
        fputs("-",fichier1);
        snprintf(mychar,sizeof(mychar),"%f \n",U) ;
        fputs(mychar, fichier1);
#endif

        label = copyLabel;
        stopEmForVolumeFeature=( (numberWhitePixel.at(time)/numberWhitePixel.at(0)<minimalRateOfCurrentWhitePixelsAdded && numberWhitePixel.at(time)>rateOfChangeForVolumefeature*numberWhitePixel.at(time-1) && numberWhitePixel.at(time)>rateOfChangeForVolumefeature*numberWhitePixel.at(time-2)) );

        if(stopEmForVolumeFeature==true)
        {
            [self polarVolumeFeature];
            cleaned=true;
            countCleaned++;
            break;
        }
        //        if (i>=3) {
        //            std::vector<double> tempVector;
        //            tempVector.push_back(sum_U_MAP.at(i-2));
        //            tempVector.push_back(sum_U_MAP.at(i-1));
        //            tempVector.push_back(sum_U_MAP.at(i));
        //            double mean = std::accumulate(tempVector.begin(), tempVector.end(), 0)/tempVector.size();
        //            std::vector<double> zero_mean(tempVector);
        //            std::transform(zero_mean.begin(), zero_mean.end(), zero_mean.begin(), std::bind2nd(std::minus<float>(), mean));
        //            double sq_sum = std::inner_product(zero_mean.begin(), zero_mean.end(), zero_mean.begin(), 0);
        //            double std = std::sqrt(sq_sum/(tempVector.size()-1));
        //            if (std/sum_U_MAP.at(i)<0.0001) {
        //                break;
        //            }
        //        }
        //snprintf(mychar,sizeof(mychar),"ITMAP: %d/%d\n",i, itMAP) ;
        //puts(mychar);
        //         fputs("               ",fichier2);
        
        #ifdef DEBUG_HMRF_DEV
         fputs("               ",fichier2);
         snprintf(mychar,sizeof(mychar),"%f",U) ;
         fputs(mychar, fichier2);
        #endif
    }
}

// clique potential
- (double)clique:(double)l :(LabelGeometryImageFilterType::LabelIndexType)index
{
    ImageTypeFloat3D::SizeType size = label->GetLargestPossibleRegion().GetSize();
    ImageTypeFloat3D::IndexType newIndex = index;
    double u2 = 0;
    
    if (index[0]-1>=0) {
        newIndex[0] = index[0]-1;
        if (l!=label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    newIndex = index;
    if (index[0]+1<360) {
        newIndex[0] = index[0]+1;
        if (l!=label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    newIndex = index;
    if (index[1]-1>=0) {
        newIndex[1] = index[1]-1;
        if (l!=label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    newIndex = index;
    if (index[1]+1<ray) {
        newIndex[1] = index[1]+1;
        if (l!=label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    newIndex = index;
    if (index[2]-1>=0) {
        newIndex[2] = index[2]-1;
        if (l!=label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    newIndex = index;
    if (index[2]+1<size[2]) {
        newIndex[2] = index[2]+1;
        if (l!=label->GetPixel(newIndex)) {
            u2 = u2 + 1/2;
        }
    }
    return u2;
}

// E Step : evaluate expectation
- (void)EStep
{
    //labelChanged=true;
    [self MAP];
    sumPly_0 = 0;
    sumPly_1 = 0;
    sumPlyY_0 = 0;
    sumPlyY_1 = 0;
    sumPlyYmu_0 = 0;
    sumPlyYmu_1 = 0;
    imageVector.erase(imageVector.begin(), imageVector.end());
    ply_0.erase(ply_0.begin(), ply_0.end());
    ply_1.erase(ply_1.begin(), ply_1.end());
    
    // for all pixels in the image space
    itk::ImageRegionConstIterator<ImageTypeFloat3D> it(image,image->GetRequestedRegion());
    it.GoToBegin();
    while (!it.IsAtEnd()) {
        double temp1_0 = 1/sqrt(2*M_PI*std1*std1) * exp(-(image->GetPixel(it.GetIndex())-mean1)*(image->GetPixel(it.GetIndex())-mean1) / (2 * std1 * std1));
        double temp1_1 = 1/sqrt(2*M_PI*std2*std2) * exp(-(image->GetPixel(it.GetIndex())-mean2)*(image->GetPixel(it.GetIndex())-mean2) / (2 * std2 *std2));
        
        double temp2_0 = [self clique:0 :it.GetIndex()];
        double temp2_1 = [self clique:1 :it.GetIndex()];
        
        ply_0.push_back(temp1_0 * exp(-temp2_0));
        ply_1.push_back(temp1_1 * exp(-temp2_1));
        double temp3 = ply_0.back() + ply_1.back();
        ply_0.back() = ply_0.back() / temp3;
        ply_1.back() = ply_1.back() / temp3;
        
        //  sum of posterior distribution for label 0 and label 1
        sumPly_0 += ply_0.back();
        sumPly_1 += ply_1.back();
        
        // sum of (posterior distribution * image pixel) for label 0 and 1
        sumPlyY_0 += ply_0.back() * image->GetPixel(it.GetIndex());
        sumPlyY_1 += ply_1.back() * image->GetPixel(it.GetIndex());
        
        imageVector.push_back(image->GetPixel(it.GetIndex()));
        ++it;
    }
}

// M Step : update parameters
- (void)MStep
{
    mean1 = sumPlyY_0/sumPly_0;
    mean2 = sumPlyY_1/sumPly_1;
    
    for (int i = 0; i<ply_0.size(); i++) {
        sumPlyYmu_0 += ply_0.at(i) * (imageVector.at(i)-mean1) * (imageVector.at(i)-mean1);
        sumPlyYmu_1 += ply_1.at(i) * (imageVector.at(i)-mean2) * (imageVector.at(i)-mean2);
    }
    
    std1 = sqrt(sumPlyYmu_0/sumPly_0);
    std2 = sqrt(sumPlyYmu_1/sumPly_1);
    
#ifdef DEBUG_HMRF_DEV
        snprintf(mychar,sizeof(mychar),"%f",mean1) ;
        fputs(mychar, fichier) ;
        fputs("         ", fichier);
        snprintf(mychar,sizeof(mychar),"%f",mean2) ;
        fputs(mychar, fichier);
        fputs("         ", fichier);
        snprintf(mychar,sizeof(mychar),"%f",std1) ;
        fputs(mychar, fichier);
        fputs("         ", fichier);
        snprintf(mychar,sizeof(mychar),"%f",std2) ;
        fputs(mychar, fichier);
        fputs("         ", fichier);
#endif

}

// EM algorithm
- (void)EM
{
    time =0 ;
    cleaned=false;
#ifdef DEBUG_HMRF_DEV
    char str[255];
    strcpy (str, LOGFILEPATH);
    strcat(str,"stats");
    char ch[3];
    strcat(str, "itEM");
    sprintf(ch, "%d", itEM);
    strcat(str, ch);
    strcat(str, "itMAP");
    sprintf(ch, "%d", itMAP);
    strcat(str, ch);
    strcat (str,".txt");
    puts (str);
    fichier = fopen(str, "a+");
    char str1[255];
    strcpy (str1, LOGFILEPATH);
    strcat (str1,"convergence");
    char ch1[3];
    strcat(str1, "itMAP");
    sprintf(ch1, "%d", itMAP);
    strcat(str1, ch1);
    strcat (str1,".txt");
    puts (str1);
    fichier1 = fopen(str1, "a+");
    char str2[255];
    strcpy (str2, LOGFILEPATH);
    strcat (str2,"convergence");
    strcat(str2, "itMAPexcell");
    sprintf(ch1, "%d", itMAP);
    strcat(str2, ch1);
    strcat (str2,".txt");
    puts (str2);
    fichier1 = fopen(str1, "a+");
    fichier2 = fopen(str2, "a+");
    snprintf(mychar,sizeof(mychar),"%f",mean1) ;
    fputs(mychar, fichier);
    fputs("         ", fichier);
    snprintf(mychar,sizeof(mychar),"%f",mean2) ;
    fputs(mychar, fichier);
    fputs("         ", fichier);
    snprintf(mychar,sizeof(mychar),"%f",std1) ;
    fputs(mychar, fichier);
    fputs("         ", fichier);
    snprintf(mychar,sizeof(mychar),"%f",std2) ;
    fputs(mychar, fichier);
#endif
    
#ifdef DEBUG_HMRF_DEV_1
    fichier1=fopen("/Users/alexandrabaluta/Documents/HMRF_Results1/IntermediateResults1(7,7).csv", "w");
    //if (!fichier)
    //    erreur
#endif
    
    std::vector<double> sum_U;
#ifdef DEBUG_HMRF_DEV
    [self polar2cartesian];
    listPix=[self initWithImage:[self relabelingForVisualisationFloat:labelCart] atSlice:indexToShow];
#endif
    
    for (int i=0; i<itEM; i++) {
        
#ifdef DEBUG_HMRF_DEV
        fputs("\nEM",fichier2);
        fputs("\n\n\n\nEM",fichier1);
        fputs("\n\n\n\nEM",fichier);
        snprintf(mychar,sizeof(mychar),"%d            ",i) ;
        fputs(mychar, fichier);
        fputs(mychar, fichier1);
#endif
        
        if (cleaned==true)
        {
            labelChanged=true;
            if (countCleaned==1)
            {
                typedef itk::MultiplyImageFilter<ImageTypeFloat3D> multiplyType;
                multiplyType::Pointer multiply = multiplyType::New();
                multiply->SetInput1(label);
                multiply->SetInput2(myocardiumPolar);
                multiply->Update();
                label = multiply->GetOutput();
                typedef itk::LabelStatisticsImageFilter <ImageTypeFloat3D,ImageTypeInt3D > LabelStatisticsImageFilter1;
                LabelStatisticsImageFilter1::Pointer statFilterHigh1= LabelStatisticsImageFilter1::New();
                typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> CastImageFilterType;
                CastImageFilterType::Pointer castImageFilterHigh = CastImageFilterType::New();
                castImageFilterHigh->SetInput(label);
                castImageFilterHigh->Update();
                statFilterHigh1->SetLabelInput(castImageFilterHigh->GetOutput());
                statFilterHigh1->SetInput(image);
                statFilterHigh1->Update();
                mean2=statFilterHigh1->GetMean(1);
                std2=statFilterHigh1->GetSigma(1);
                mean1=statFilterHigh1->GetMean(0);
                std1=statFilterHigh1->GetSigma(0);
                multiplywithmyo=true;
            }
        }
        [self EStep];
        [self MStep];

        sum_U.push_back(U);
        
#ifdef DEBUG_HMRF_DEV
        [self polar2cartesian];
        [self addImage:[self relabelingForVisualisationFloat:labelCart] toPixList:listPix atSlice:indexToShow];
        b=b+1;
#endif
        
        // if it converges, stop the loop
        sum_U.push_back(U);
        if (i>=3) {
            std::vector<double> tempVector;
            tempVector.push_back(sum_U.at(i-3));
            tempVector.push_back(sum_U.at(i-2));
            tempVector.push_back(sum_U.at(i-1));
            tempVector.push_back(sum_U.at(i));
            double min = *min_element(tempVector.begin(), tempVector.end());
            double max = *max_element(tempVector.begin(), tempVector.end());
            double h=100*fabs(min/max-1);
            if (h< rateToStop && multiplywithmyo==true)// && numberWhitePixel.at(time)<0.001*numberWhitePixel.at(0))
            {
                break;
            }
        }
        //snprintf(mychar,sizeof(mychar),"ITEM: %d/%d\n",i, itEM);
        //puts(mychar);
    }
    labelChanged=true;

#ifdef DEBUG_HMRF_DEV
    fclose(fichier);
    fclose(fichier1);
    fclose(fichier2);
    NSData *volumeData =[[NSMutableData alloc] autorelease];
      volumeData= [[self.volumeWindow viewerController]volumeData];
      NSMutableArray *array = [NSMutableArray arrayWithArray:[[[self.volumeWindow viewerController] fileList] subarrayWithRange:NSMakeRange(0,1)]];
      NSMutableArray *newFileArray = [[NSMutableArray alloc]initWithCapacity:b+1];
      for (int i=0; i< b+1; i++)
    {
        [newFileArray addObjectsFromArray:array];
    }
    //    NSMutableArray *newFileArray1 = [[NSMutableArray alloc]initWithCapacity:b];
    //    for (int i=0; i<b+1; i++)
    //    {
    //        [newFileArray1 addObject:[[listPix objectAtIndex:i]image]];
    //   }
    //    NSMutableArray *newFileArray = [NSMutableArray arrayWithCapacity:b+1];
    ViewerController *viewerControll=[[ViewerController alloc] newWindow:listPix :newFileArray :volumeData];
    [self drawEndoEpicWithView:viewerControll atSlice:indexToShow];
   // newFileArray1 =[NSMutableArray arrayWithArray:[viewerControll fileList]];
   // [[viewerControll pixList]addObject:listPix];
   // J'ai remplace firstPIx avec listPix parce que autrement je obtenais une erreure
   // [viewerControll needsDisplayUpdate];
#endif

#ifdef DEBUG_HMRF_DEV_1
    fclose(fichier1);
#endif
}

// get the OSIROIMask of the mask in ITK
- (void)MaskWithsliceOfImage:(int)sliceOfImage sliceOfRoi:(int)sliceOfRoi :(ImageTypeFloat3D::Pointer)img :(NSString*)name
{
    ImageTypeFloat3D::SizeType size = img->GetLargestPossibleRegion().GetSize();
    NSMutableArray *infarctArray  = [[[NSMutableArray alloc] init] autorelease];
    
    for (int h = 0; h<size[1]; h++) {
        for (int w=0; w<size[0]; w++) {
            ImageTypeFloat3D::IndexType pixelIndex;
            pixelIndex[0] = w;   // x position
            pixelIndex[1] = h;   // y position
            pixelIndex[2] = sliceOfImage;   // z position
            
            if (abs(img->GetPixel(pixelIndex))>0) {
                NSRange width = NSMakeRange(w, 1);
                OSIROIMaskRun run;
                run.widthRange = width;
                run.heightIndex = h;
                run.depthIndex = sliceOfRoi;
                run.intensity = 255;
                NSValue *miValue = [NSValue value: &run withObjCType:@encode(OSIROIMaskRun)];
                [infarctArray addObject:miValue];
            }
        }
    }
    OSIROIMask *Mask = [[[OSIROIMask alloc] initWithMaskRuns:infarctArray] autorelease];
    OSIFloatVolumeData *floatVolumeData = [self.volumeWindow floatVolumeDataForDimensionsAndIndexes:@"movieIndex", [NSNumber numberWithInteger:0], nil];
    
    OSIMaskROI *Roi =  [[[OSIMaskROI alloc] initWithROIMask:Mask homeFloatVolumeData:floatVolumeData name:name] autorelease];
    [[self.volumeWindow ROIManager]addROI:Roi];
    
}

// polar coordinates to cartesian coordinates
- (void)polar2cartesian
{
    // new image in cartesian coordinates
    ImageTypeFloat3D::Pointer image3D = ImageTypeFloat3D::New();
    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    //NSUInteger slices = [[viewControl pixList] count];
    ImageTypeFloat3D::SizeType size;
    ImageTypeFloat3D::IndexType start;
    ImageTypeFloat3D::RegionType region;
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    size[2] = slicesNumber;
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    image3D->SetRegions(region);
    image3D->Allocate();
    image3D->FillBuffer(0);
    
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> CastImageFilterType;
    CastImageFilterType::Pointer castImageFilter = CastImageFilterType::New();
    castImageFilter->SetInput(label);
    castImageFilter->Update();
    
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
    labelGeometryImageFilter->SetInput( castImageFilter->GetOutput() );
    labelGeometryImageFilter->CalculatePixelIndicesOn();
    labelGeometryImageFilter->Update();
    LabelGeometryImageFilterType::LabelsType allLabels = labelGeometryImageFilter->GetLabels();
    LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt;
    
    LabelGeometryImageFilterType::LabelPixelType labelValue = *(allLabels.begin()+1);
    std::vector<LabelGeometryImageFilterType::LabelIndexType> vect = labelGeometryImageFilter->GetPixelIndices(labelValue);
    
    // for all pixels which are infarcted
    for (int i=0; i<vect.size(); i++) {
        ImageTypeFloat3D::IndexType index = vect.at(i);
        // transform its coordinates
        double thetaRad = M_PI*index[0]/180;
        double x = index[1]*cos(thetaRad) + center.x;
        double y = -index[1]*sin(thetaRad) + center.y;
        double z = index[2];
        
        ImageTypeFloat3D::IndexType indexCart;
        indexCart[0] = floor(x);
        indexCart[1] = floor(y);
        indexCart[2] = z;
        image3D->SetPixel(indexCart, label->GetPixel(index));
    }
    labelCart = image3D;
}

// fill the hole to find no reflow
- (void)Close
{
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> castTypeIF;
    castTypeIF::Pointer castIF = castTypeIF::New();
    castIF->SetInput(labelCart);
    castIF->Update();
    typedef itk::SubtractImageFilter <ImageTypeInt3D, ImageTypeInt3D >SubtractImageFilterType;
    SubtractImageFilterType::Pointer subtractFilter= SubtractImageFilterType::New ();
    subtractFilter->SetInput1(myocardium);
    subtractFilter->SetInput2(castIF->GetOutput());
    subtractFilter->Update();
    ImageTypeInt3D::Pointer image3D=subtractFilter->GetOutput();
    //[self copyIntImage3D:[self relabelingForVisualisationInt:image3D]];
    for(int l=0;l<slicesNumber;l++){
        ImageTypeInt2D::Pointer noReflow2D = ImageTypeInt2D::New();
        // ImageTypeInt2D::Pointer intermediateImage = ImageTypeInt2D::New();
        DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
        // NSUInteger slices = [[viewControl pixList] count];
        ImageTypeInt2D::SizeType size;
        ImageTypeInt2D::IndexType start;
        ImageTypeInt2D::RegionType region;
        size[0] = [firstPix pwidth];
        size[1] = [firstPix pheight];
        start.Fill(0);
        region.SetIndex(start);
        region.SetSize(size);
        noReflow2D->SetRegions(region);
        noReflow2D->Allocate();
        noReflow2D->FillBuffer(0);
        //        intermediateImage->SetRegions(region);
        //        intermediateImage->Allocate();
        //        intermediateImage->FillBuffer(0);
        itk::ImageRegionConstIterator<ImageTypeInt2D> it(noReflow2D,noReflow2D->GetLargestPossibleRegion());//region est une région contenant le myocarde
        it.GoToBegin();//
        while (!it.IsAtEnd()) {
            ImageTypeInt3D::IndexType index;
            index[0]=it.GetIndex()[0];
            index[1]=it.GetIndex()[1];
            index[2]=l;
            int h=image3D->GetPixel(index);
            if (h>0){
                noReflow2D->SetPixel(it.GetIndex(),1);
            }
            ++it;
        }
        typedef itk::ConnectedComponentImageFilter <ImageTypeInt2D, ImageTypeInt2D> ConnectedComponentImageFilterType;
        ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
        labelFilter->SetFullyConnected(false);
        labelFilter->SetInput(noReflow2D);
        labelFilter->Update();
        noReflow2D=labelFilter->GetOutput();
        typedef itk::LabelGeometryImageFilter< ImageTypeInt2D > LabelGeometryImageFilterType;
        LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
        labelGeometryImageFilter->SetInput(labelFilter->GetOutput());
        labelGeometryImageFilter->CalculatePixelIndicesOn();
        labelGeometryImageFilter->Update();
        LabelGeometryImageFilterType::LabelsType allLabels = labelGeometryImageFilter->GetLabels();
        LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt;
        for( allLabelsIt = allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
        {
            LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
            std::vector<LabelGeometryImageFilterType::LabelIndexType> indices = labelGeometryImageFilter->GetPixelIndices(labelValue);
            int count;
            count=0;
            for (int i=0; i<indices.size(); i++)
            {
                ImageTypeInt2D::IndexType idx;
                idx[0] = indices.at(i)[0];
                idx[1] = indices.at(i)[1];
                //idx[2] = indices.at(i)[2];
                if (noReflow2D->GetPixel(idx)>0)
                {
                    count=count+1;
                }
            }
            if (count>myoSize.at(l)*rateOfSize)
            {
                for (int i=0; i<indices.size(); i++) {
                    ImageTypeInt2D::IndexType idx;
                    idx[0] = indices.at(i)[0];
                    idx[1] = indices.at(i)[1];
                    noReflow2D->SetPixel(idx, 0);
                    //                    ImageTypeInt3D::IndexType idx1;
                    //                    idx1[0] = indices.at(i)[0];
                    //                    idx1[1] = indices.at(i)[1];
                    //                    idx1[2] = l;
                    //                    image3D->SetPixel(idx1,0);
                }
                continue;
            }
            //        }
            //        for( allLabelsIt = allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
            //        {
            //            LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
            //            std::vector<LabelGeometryImageFilterType::LabelIndexType> indices = labelGeometryImageFilter->GetPixelIndices(labelValue);
            typedef itk::CastImageFilter<ImageTypeInt2D, ImageTypeFloat2D> castTypeIF;
            castTypeIF::Pointer castIF = castTypeIF::New();
            castIF->SetInput(noReflow2D);
            castIF->Update();
            typedef itk::ThresholdImageFilter <ImageTypeFloat2D> ThresholdImageFilterType;
            ThresholdImageFilterType::Pointer thresholdFilter = ThresholdImageFilterType::New();
            thresholdFilter->SetInput(castIF->GetOutput());
            float h1=labelValue-0.50;
            float h2=labelValue+0.50;
            //thresholdFilter->SetLower(h1);
            //thresholdFilter->SetUpper(h2);
            thresholdFilter->ThresholdOutside(h1, h2);
            thresholdFilter->SetOutsideValue(0);
            thresholdFilter->Update();
            typedef itk::BinaryContourImageFilter<ImageTypeFloat2D, ImageTypeFloat2D> BinaryContourImageFilterType;
            BinaryContourImageFilterType::Pointer binaryContourImageFilter = BinaryContourImageFilterType::New();
            binaryContourImageFilter->SetInput(thresholdFilter->GetOutput());
            binaryContourImageFilter->SetForegroundValue(0);
            binaryContourImageFilter->SetBackgroundValue(labelValue);
            binaryContourImageFilter->Update();
            //[self copyImage:binaryContourImageFilter->GetOutput()];
            //break;
            typedef itk::CastImageFilter<ImageTypeFloat2D, ImageTypeInt2D> CastImageFilterType1;
            CastImageFilterType1::Pointer castImageFilter1 = CastImageFilterType1::New();
            castImageFilter1->SetInput(binaryContourImageFilter->GetOutput());
            castImageFilter1->Update();
            
            LabelGeometryImageFilterType::Pointer labelGeometryImageFilter1 = LabelGeometryImageFilterType::New();
            labelGeometryImageFilter1->SetInput( castImageFilter1->GetOutput() );
            labelGeometryImageFilter1->CalculatePixelIndicesOn();
            labelGeometryImageFilter1->Update();
            LabelGeometryImageFilterType::LabelsType allLabels1 = labelGeometryImageFilter1->GetLabels();
            LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt1;
            //intermediateImage=castImageFilter1->GetOutput();
            std::vector<LabelGeometryImageFilterType::LabelIndexType> vect;
            for( allLabelsIt1 = allLabels1.begin(); allLabelsIt1 != allLabels1.end(); allLabelsIt1++ )
            {
                LabelGeometryImageFilterType::LabelPixelType labelValue1 = *allLabelsIt1;
                if (labelValue1==0) {
                    vect = labelGeometryImageFilter1->GetPixelIndices(labelValue1);
                    break;
                }
            }
            nonInfarctNeighboor=0;
            for (int j=0; j<vect.size(); j++) {
                ImageTypeFloat3D::IndexType index;
                index[0]=vect.at(j)[0];
                index[1]=vect.at(j)[1];
                index[2]=l;
                if (labelCart->GetPixel(index)==0)
                {
                    nonInfarctNeighboor++;
                }
            }
            if(nonInfarctNeighboor>rateOfNonInfartedNeighbor*vect.size())
            {
                typedef itk::SubtractImageFilter <ImageTypeInt2D, ImageTypeInt2D >SubtractImageFilterType;
                SubtractImageFilterType::Pointer subtractFilter= SubtractImageFilterType::New ();
                subtractFilter->SetInput1(noReflow2D);
                CastImageFilterType1::Pointer castImageFilter2 = CastImageFilterType1::New();
                castImageFilter2->SetInput(thresholdFilter->GetOutput());
                castImageFilter2->Update();
                subtractFilter->SetInput2(castImageFilter2->GetOutput());
                subtractFilter->Update();
                noReflow2D=subtractFilter->GetOutput();
                for (int i=0; i<indices.size(); i++) {
                    ImageTypeInt3D::IndexType idx;
                    idx[0] = indices.at(i)[0];
                    idx[1] = indices.at(i)[1];
                    idx[2] = l;
                    image3D->SetPixel(idx, 0);
                }
            }
        }
        
        
        itk::ImageRegionConstIterator<ImageTypeInt2D> it1(noReflow2D,noReflow2D->GetLargestPossibleRegion());//region est une région contenant le myocarde
        it1.GoToBegin();//
        while (!it1.IsAtEnd()) {
            //ImageTypeFloat3D=
            ImageTypeInt3D::IndexType idx;
            idx[0] = it1.GetIndex()[0];
            idx[1] = it1.GetIndex()[1];
            idx[2] = l;
            image3D->SetPixel(idx, noReflow2D->GetPixel(it1.GetIndex()));
            ++it1;
        }
        
    }
    //    [self copyIntImage3D:[self relabelingForVisualisationInt:image3D]];
    typedef itk::CastImageFilter<ImageTypeInt3D , ImageTypeFloat3D> castTypeIF1;
    castTypeIF1::Pointer castIF1 = castTypeIF1::New();
    castIF1->SetInput(image3D);
    castIF1->Update();
    noReflowCart=castIF1->GetOutput();
    //   [self copyFloatImage3D:[self relabelingForVisualisationFloat:binaryContourImageFilter->GetOutput()]];
    
    
    //    typedef itk::RelabelComponentImageFilter<ImageTypeFloat3D, ImageTypeInt3D> FilterType;
    //    FilterType::Pointer relabelFilter = FilterType::New();
    //    relabelFilter->SetInput( castIF1->GetOutput() );
    //
    //    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    //    float volumeOfPixelMm3 = [firstPix pixelSpacingX]*[firstPix pixelSpacingY]*[firstPix sliceInterval];
    //    int minsize = round( minVolumeInMm3/volumeOfPixelMm3 );
    //    relabelFilter->SetMinimumObjectSize( minsize );
    //    relabelFilter->Update();
    //
    //    noReflowCart = castIF->GetOutput();
    //    [self copyFloatImage3D:[self relabelingForVisualisationFloat:noReflowCart]];
    
    
    // Les instructions suivantes ne sont pas utilisées comme des commentaires dans la version Amine
    
    
    //    // binary image
    //    typedef itk::BinaryThresholdImageFilter <ImageTypeFloat3D, ImageTypeFloat3D> BinaryThresholdImageFilterType;
    //    BinaryThresholdImageFilterType::Pointer thresholdFilter = BinaryThresholdImageFilterType::New();
    //    thresholdFilter->SetInput(labelCart);
    //    ImageTypeFloat3D::SizeType size=labelCart->GetLargestPossibleRegion().GetSize();
    //    thresholdFilter->SetLowerThreshold(0);
    //    thresholdFilter->SetUpperThreshold(0.1);
    //    thresholdFilter->SetInsideValue(0);
    //    thresholdFilter->SetOutsideValue(100);
    //    thresholdFilter->Update();
    //    typedef itk::VotingBinaryIterativeHoleFillingImageFilter<ImageTypeFloat3D > FilterType;
    //    FilterType::Pointer filter = FilterType::New();
    //    ImageTypeFloat3D::SizeType indexRadius;
    //    indexRadius[0] = 3; // radius along x
    //    indexRadius[1] = 3; // radius along y
    //    indexRadius[2] = 0; // radius along y
    //    filter->SetRadius( indexRadius );
    //    filter->SetBackgroundValue( 0 );
    //    filter->SetForegroundValue( 100 );
    //    filter->SetMajorityThreshold( 3 );
    //    filter->SetMaximumNumberOfIterations( 100 );
    //    filter->SetInput( thresholdFilter->GetOutput() );
    //    filter->Update();
    //    typedef itk::SubtractImageFilter <ImageTypeFloat3D, ImageTypeFloat3D > SubtractImageFilterType;
    //    SubtractImageFilterType::Pointer subtractFilter = SubtractImageFilterType::New ();
    //    subtractFilter->SetInput1(filter->GetOutput());
    //    subtractFilter->SetInput2(thresholdFilter->GetOutput());
    //    subtractFilter->Update();
    
    // et a la fin + cette instruction
    // noReflowCart = subtractFilter->GetOutput();
    
}

// compute the mask of the endocardium contour for the feature analysis
- (ImageTypeInt3D::Pointer)ComputeEndoContour
{
    ImageTypeInt3D::Pointer endoContour = ImageTypeInt3D::New();
    ImageTypeInt3D::SizeType size;
    ImageTypeInt3D::IndexType start;
    ImageTypeInt3D::RegionType region;
    
    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    //NSUInteger slices = [[viewControl pixList] count];
    
    //Size Width * Height * NoOfSlices
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    size[2] = slicesNumber ;
    
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    endoContour->SetRegions(region);
    endoContour->Allocate();
    endoContour->FillBuffer(0);
    ImageTypeFloat3D::PixelType   pixelValue;
    pixelValue =  (float)1;
    imageDepth=0;
    NSMutableArray  *roiSeriesList = [viewControl roiList];
    if ([self slice])
    {
        for (int numSeries=0;numSeries<[roiSeriesList count]; numSeries++) {
            // All rois contained in the current image
            NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
            for (int numROI=0; numROI<[roiImageList count]; numROI++) {
                if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
                    ROI *endoBaseROI = [roiImageList objectAtIndex:numROI];
                    NSMutableArray  *pts = [endoBaseROI points];
                    for (int numPts = 0; numPts < [pts count]; numPts++)
                    {
                        MyPoint *point = [pts objectAtIndex:numPts];
                        ImageTypeFloat3D::IndexType pixelIndex;
                        pixelIndex[0] = point.x;   // x position
                        pixelIndex[1] = point.y;   // y position
                        pixelIndex[2] = imageDepth;   // z position
                        endoContour->SetPixel(   pixelIndex,   pixelValue  );
                    }
                }
            }
            [viewControl setImageIndex:numSeries];
            OSIROI* outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];
            OSIROI* insideROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
            
            // in Amine's version
            // OSIROI* outsideROI = [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"];
            //OSIROI* insideROI = [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"];
            
            if (outsideROI && insideROI) {
                imageDepth=imageDepth+1;
            }
        }
    }
    else
    {
        for (int numSeries=[roiSeriesList count]-1;numSeries>=0; numSeries--) {
            // All rois contained in the current image
            NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
            for (int numROI=0; numROI<[roiImageList count]; numROI++) {
                if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
                    ROI *endoBaseROI = [roiImageList objectAtIndex:numROI];
                    NSMutableArray  *pts = [endoBaseROI points];
                    for (int numPts = 0; numPts < [pts count]; numPts++)
                    {
                        MyPoint *point = [pts objectAtIndex:numPts];
                        ImageTypeFloat3D::IndexType pixelIndex;
                        pixelIndex[0] = point.x;   // x position
                        pixelIndex[1] = point.y;   // y position
                        pixelIndex[2] = imageDepth;   // z position
                        endoContour->SetPixel(   pixelIndex,   pixelValue  );
                    }
                }
            }
            [viewControl needsDisplayUpdate];
            [viewControl setImageIndex:[roiSeriesList count]-1-numSeries];
            OSIROI* outsideROI = [[self.volumeWindow ROIManager] visibleEpicardialROI];
            OSIROI* insideROI = [[self.volumeWindow ROIManager] visibleEndocardialROI];
            
            // in Amine's version
            // OSIROI* outsideROI = [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"];
            //OSIROI* insideROI = [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"];
            
            if (outsideROI && insideROI) {
                imageDepth=imageDepth+1;
            }
        }
    }
    // connected component
    typedef itk::ConnectedComponentImageFilter <ImageTypeInt3D, ImageTypeInt3D> ConnectedComponentImageFilterType;
    ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
    labelFilter->SetInput(endoContour);
    labelFilter->Update();
    return(labelFilter->GetOutput());
}

// compute the mask of the endocardium contour for the feature analysis
#ifdef DEBUG_HMRF_DEV
- (ImageTypeInt3D::Pointer)ComputeEndoContourOld
{
    ImageTypeInt3D::Pointer endoContour = ImageTypeInt3D::New();
    ImageTypeInt3D::SizeType size;
    ImageTypeInt3D::IndexType start;
    ImageTypeInt3D::RegionType region;
    
    DCMPix *firstPix = [[[self.volumeWindow viewerController] pixList] objectAtIndex:0];
    NSUInteger slices = [[[self.volumeWindow viewerController] pixList] count];
    
    //Size Width * Height * NoOfSlices
    size[0] = [firstPix pwidth];
    size[1] = [firstPix pheight];
    size[2] = slices;
    
    start.Fill(0);
    region.SetIndex(start);
    region.SetSize(size);
    endoContour->SetRegions(region);
    endoContour->Allocate();
    endoContour->FillBuffer(0);
    ImageTypeFloat3D::PixelType   pixelValue;
    pixelValue =  (float)1;
    
    NSMutableArray  *roiSeriesList = [[self.volumeWindow viewerController] roiList];
    for (int numSeries=0;numSeries<[roiSeriesList count]; numSeries++) {
        // All rois contained in the current image
        NSMutableArray  *roiImageList = [roiSeriesList objectAtIndex: numSeries];
        for (int numROI=0; numROI<[roiImageList count]; numROI++) {
            if ([[[roiImageList objectAtIndex:numROI]name]isEqualToString:@"CMRSegTools: Endocardium"]) {
                ROI *endoBaseROI = [roiImageList objectAtIndex:numROI];
                NSMutableArray  *pts = [endoBaseROI points];
                for (int numPts = 0; numPts < [pts count]; numPts++)
                {
                    MyPoint *point = [pts objectAtIndex:numPts];
                    ImageTypeFloat3D::IndexType pixelIndex;
                    pixelIndex[0] = point.x;   // x position
                    pixelIndex[1] = point.y;   // y position
                    pixelIndex[2] = numSeries;   // z position
                    endoContour->SetPixel(   pixelIndex,   pixelValue  );
                }
            }
        }
    }
    // connected component
    typedef itk::ConnectedComponentImageFilter <ImageTypeInt3D, ImageTypeInt3D> ConnectedComponentImageFilterType;
    ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
    labelFilter->SetInput(endoContour);
    labelFilter->Update();
    return(labelFilter->GetOutput());
}

// distance analysis
- (void)DistanceFeature:(ImageTypeInt3D::Pointer)imageLabel endoMask:(ImageTypeInt3D::Pointer)endoMask
{
    typedef itk::LabelGeometryImageFilter< ImageTypeInt3D > LabelGeometryImageFilterType;
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
    labelGeometryImageFilter->SetInput( imageLabel );
    labelGeometryImageFilter->CalculatePixelIndicesOn();
    labelGeometryImageFilter->Update();
    LabelGeometryImageFilterType::LabelsType allLabels = labelGeometryImageFilter->GetLabels();
    LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt;
    
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilterEndo = LabelGeometryImageFilterType::New();
    labelGeometryImageFilterEndo->SetInput( endoMask );
    labelGeometryImageFilterEndo->CalculatePixelIndicesOn();
    labelGeometryImageFilterEndo->Update();
    LabelGeometryImageFilterType::LabelsType allLabelsEndo = labelGeometryImageFilterEndo->GetLabels();
    LabelGeometryImageFilterType::LabelsType::iterator allLabelsItEndo;
    
    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    std::vector<float> distance;
    int indexVector = 0;
    
    for( allLabelsIt = allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
    {
        distance.push_back(1.5);
        LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
        std::vector<LabelGeometryImageFilterType::LabelIndexType> vect = labelGeometryImageFilter->GetPixelIndices(labelValue);
        for( allLabelsItEndo = allLabelsEndo.begin()+1; allLabelsItEndo != allLabelsEndo.end(); allLabelsItEndo++ )
        {
            LabelGeometryImageFilterType::LabelPixelType labelValueEndo = *allLabelsItEndo;
            std::vector<LabelGeometryImageFilterType::LabelIndexType> indicesEndo = labelGeometryImageFilterEndo->GetPixelIndices(labelValueEndo);
            for (int i=0; i<vect.size(); i++) {
                for (int j=0; j<indicesEndo.size(); j++) {
                    if (vect.at(i)[2]==indicesEndo.at(j)[2]) {
                        
                        itk::Point<float,3> p0;
                        p0[0] = vect.at(i)[0];
                        p0[1] = vect.at(i)[1];
                        p0[2] = vect.at(i)[2];
                        itk::Point<float,3> p1;
                        p1[0] = indicesEndo.at(j)[0];
                        p1[1] = indicesEndo.at(j)[1];
                        p1[2] = indicesEndo.at(j)[2];
                        
                        double dist = p0.EuclideanDistanceTo(p1);
                        if (dist/[firstPix pixelSpacingX]<distance.at(indexVector)) {
                            distance.at(indexVector) = dist/[firstPix pixelSpacingX];
                        }
                    }
                }
            }
        }
        indexVector +=1;
    }
    // remove all labels which have a distance to endocardium > 1.5mm
    indexVector = 0;
    for( allLabelsIt = allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
    {
        LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
        std::vector<LabelGeometryImageFilterType::LabelIndexType> vect = labelGeometryImageFilter->GetPixelIndices(labelValue);
        if ( distance.at(indexVector)>=1.5) {
            for (int i=0; i<vect.size(); i++) {
                ImageTypeFloat3D::IndexType pixelIndex;
                pixelIndex[0] = vect.at(i)[0];   // x position
                pixelIndex[1] = vect.at(i)[1];   // y position
                pixelIndex[2] = vect.at(i)[2];   // z position
                imageLabel->SetPixel(pixelIndex, 0);
            }
        }
        indexVector+=1;
    }
    
    typedef itk::CastImageFilter<ImageTypeInt3D, ImageTypeFloat3D> castTypeIF;
    castTypeIF::Pointer castIF = castTypeIF::New();
    castIF->SetInput(imageLabel);
    castIF->Update();
    labelCart = castIF->GetOutput();
}
#endif

// volume analysis
- (ImageTypeInt3D::Pointer)volumeFeature
{
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> castTypeFI;
    castTypeFI::Pointer castFI = castTypeFI::New();
    castFI->SetInput(labelCart);
    castFI->Update();
    
    typedef itk::MultiplyImageFilter<ImageTypeInt3D> multiplyType;
    multiplyType::Pointer multiply = multiplyType::New();
    multiply->SetInput1(castFI->GetOutput());
    multiply->SetInput2(myocardium);
    multiply->Update();
    
    
    typedef itk::ConnectedComponentImageFilter <ImageTypeInt3D, ImageTypeInt3D> ConnectedComponentImageFilterType;
    ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
    labelFilter->SetInput(multiply->GetOutput());
    labelFilter->Update();
    
    // myocardium density = 1.055 g/cm3
    // remove all labels which have a mass < 0.1g
    typedef itk::RelabelComponentImageFilter<ImageTypeInt3D, ImageTypeInt3D> FilterType;
    FilterType::Pointer relabelFilter = FilterType::New();
    relabelFilter->SetInput( labelFilter->GetOutput() );
    float minVolumeInMm3 = 0.1/(1.05*0.001);
    
    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    float volumeOfPixelMm3 = [firstPix pixelSpacingX]*[firstPix pixelSpacingY]*[firstPix sliceInterval];
    int minsize = round( minVolumeInMm3/volumeOfPixelMm3 );
    relabelFilter->SetMinimumObjectSize(multiplyingFactorOfVolumeFeature*minsize );
    relabelFilter->Update();
    
    return relabelFilter->GetOutput();
}
-(void)polarVolumeFeature
{
    typedef itk::MultiplyImageFilter<ImageTypeFloat3D> multiplyType;
    multiplyType::Pointer multiply = multiplyType::New();
    multiply->SetInput1(label);
    multiply->SetInput2(myocardiumPolar);
    multiply->Update();
    typedef itk::CastImageFilter<ImageTypeFloat3D, ImageTypeInt3D> castTypeFI;
    castTypeFI::Pointer castFI = castTypeFI::New();
    castFI->SetInput(multiply->GetOutput());
    castFI->Update();
    
    typedef itk::ConnectedComponentImageFilter <ImageTypeInt3D, ImageTypeInt3D> ConnectedComponentImageFilterType;
    ConnectedComponentImageFilterType::Pointer labelFilter = ConnectedComponentImageFilterType::New();
    labelFilter->SetInput(castFI->GetOutput());
    labelFilter->Update();
    typedef itk::LabelGeometryImageFilter< ImageTypeInt3D > LabelGeometryImageFilterType;
    LabelGeometryImageFilterType::Pointer labelGeometryImageFilter = LabelGeometryImageFilterType::New();
    labelGeometryImageFilter->SetInput( labelFilter->GetOutput() );
    labelGeometryImageFilter->CalculatePixelIndicesOn();
    labelGeometryImageFilter->Update();
    LabelGeometryImageFilterType::LabelsType allLabels = labelGeometryImageFilter->GetLabels();
    LabelGeometryImageFilterType::LabelsType::iterator allLabelsIt;
    float minVolumeInMm3 = 0.1/(1.05*0.001);
    DCMPix *firstPix = [[viewControl pixList] objectAtIndex:0];
    float volumeOfPixelMm3 = [firstPix pixelSpacingX]*[firstPix pixelSpacingY]*[firstPix spacingBetweenSlices];
    volumeOfPixelMm3 = [firstPix pixelSpacingX]*[firstPix pixelSpacingY]*[firstPix sliceInterval];
    // float minsize = round( minVolumeInMm3/volumeOfPixelMm3 ); // commented unused variable -spalte
    
    for( allLabelsIt= allLabels.begin()+1; allLabelsIt != allLabels.end(); allLabelsIt++ )
    {
        int volumeSize=0;
        LabelGeometryImageFilterType::LabelPixelType labelValue = *allLabelsIt;
        std::vector<LabelGeometryImageFilterType::LabelIndexType> indices = labelGeometryImageFilter->GetPixelIndices(labelValue);
        ImageTypeFloat3D::IndexType p1;
        for (int j=0; j<indices.size(); j++) {
            p1[0] = indices.at(j)[0];
            p1[1] = indices.at(j)[1];
            p1[2] = indices.at(j)[2];
            volumeSize=volumeSize+[firstPix sliceInterval]*M_PI*(2*p1[1]-1)/360;
        }
        if ( volumeSize < minVolumeInMm3)
        {
            for (int j=0; j<indices.size(); j++) {
                p1[0] = indices.at(j)[0];
                p1[1] = indices.at(j)[1];
                p1[2] = indices.at(j)[2];
                label->SetPixel(p1, 0);
                image->SetPixel(p1, 0);
            }
        }
    }
    
}

// test if the image is defined anterior to posterior or right->left
- (BOOL)slice
{
    //ViewerController *viewerController = viewControl;
    int curIndex = [[viewControl imageView]curImage];
    NSString        *dicomTag = @"0020,0013";
    NSArray         *pixList = [viewControl  pixList: 0];
    DCMPix          *curPix = [pixList objectAtIndex: curIndex];
    NSString        *file_path = [curPix sourceFile];
    DCMObject       *dcmObj = [DCMObject objectWithContentsOfFile:file_path decodingPixelData:NO];
    DCMAttributeTag *tag = [[[DCMAttributeTag alloc] initWithName:dicomTag] autorelease];
    if (!tag) tag = [DCMAttributeTag tagWithTagString:dicomTag];
    NSString        *val;
    DCMAttribute    *attr;
    attr = [dcmObj attributeForTag:tag];
    val = [[attr value] description];
    NSString *stringVal=[[[NSString alloc] initWithString:val]autorelease];
    int valint=[stringVal intValue];
    BOOL rep;
    if (curIndex+1==valint) {
        rep = true;
    }
    else
        rep = false;
    return rep;
}

- (void)compute
{
    multiplyingFactorOfVolumeFeature=MULTIPLYINGFACTOROFVOLUMEFEATURE;
    initialThreshold=INITIALTHRESHOLD;
    rateToStop=RATETOSTOP;
    rateOfSize=RATEOSSIZE;
    rateOfNonInfartedNeighbor=RATEOFNONINFARTEDNEIGHBOR;
    rateOfChangeForVolumefeature=RATEOFCHANGEFORVOLUMEFEATURE;
    minimalRateOfCurrentWhitePixelsAdded=MINIMALRATEOFCURRENTWHITEPIXELSADDED;
    itMAP = ITMAPMAX;
    itEM = ITEMMAX;
    multiplywithmyo=false;
    labelChanged=true;
    cleaned=false;
    countCleaned=0;
    stopEmForVolumeFeature=false;
    
    // compute each slice on the polar coordinates
    [self imagePolar];
    // EM algorithm
    [self EM];
    // return in cartesian coordinates
    [self polar2cartesian];
    // volume analysis
    ImageTypeInt3D::Pointer imageAfterVolumeAnalysis = [self volumeFeature];
    // compute the mask of the endocardium (needed for the distance analysis)
    ImageTypeInt3D::Pointer endoImage = [self ComputeEndoContour];
    // distance analysis
    [self DistanceFeature:imageAfterVolumeAnalysis endoMask:endoImage];
    // fill the holes for no reflow
    [self Close];
    
    // through the images to add on each image the OSIROI of infarct and no reflow
    //ViewerController *viewerController = [self.volumeWindow viewerController];
    int curIndex = [[viewControl imageView]curImage];
    BOOL sliceIndex = [self slice];
    NSMutableArray  *roiSeriesList  = [viewControl roiList];
    imageDepth=0;
    if (sliceIndex)
    {
        for (int j=0; j<[roiSeriesList count]; j++) {
            [viewControl setImageIndex:j];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                [self MaskWithsliceOfImage:imageDepth sliceOfRoi:j :labelCart :@"hmrfMask"];
                [self MaskWithsliceOfImage:imageDepth sliceOfRoi:j :noReflowCart :@"hmrf: No-reflow;no"];
                imageDepth=imageDepth+1;
            }
        }
    }
    else
    {
        for (int j=[roiSeriesList count]-1;j>=0; j--) {
            [viewControl setImageIndex:[roiSeriesList count]-j-1];
            if ([[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Epicardium"] && [[self.volumeWindow ROIManager]firstVisibleROIWithName:@"CMRSegTools: Endocardium"])
            {
                [self MaskWithsliceOfImage:imageDepth sliceOfRoi:j :labelCart :@"hmrfMask"];
                [self MaskWithsliceOfImage:imageDepth sliceOfRoi:j :noReflowCart :@"hmrf: No-reflow;no"];
                imageDepth=imageDepth+1;
            }
        }
    }
    
    if (sliceIndex) {
        [viewControl setImageIndex:curIndex];
    }
    else
    {
        [viewControl setImageIndex:(int)[roiSeriesList count]-curIndex-1];
        for (int j=0; j<[roiSeriesList count]; j++) {
            [viewControl setImageIndex:j];
        }
        [viewControl setImageIndex:(int)[roiSeriesList count]-curIndex-1];
    }
}
-(void) dealloc
{
    //    [viewControl release];
    //    viewControl = nil;
    //    [_volumeWindow release];
    //    _volumeWindow = nil;
    [super dealloc];
}

@end