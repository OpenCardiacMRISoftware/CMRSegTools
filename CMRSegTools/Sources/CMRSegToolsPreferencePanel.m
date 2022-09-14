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
//  CMRSegToolsPreferencePanel.m
//  CMRSegTools
//
//  Created by Joël Spaltenstein on 10/15/13.
//  Copyright (c) 2013 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRSegToolsPreferencePanel.h"
#import "CMRSegTools.h"

@interface CMRSegToolsPreferencePanel ()

@property (weak) IBOutlet NSArrayController *filters;
@property (weak) IBOutlet NSView *preferenceView;
@property (weak) IBOutlet NSTableView *filtersTable;

@end

static NSString * const CMRT1FilterType = @"fr.insa-lyon.creatis.cmrsegtools.t1.filter.row";

@implementation CMRSegToolsPreferencePanel

@synthesize preferenceView = _preferenceView;
@synthesize filtersTable = _filtersTable;

- (id) initWithBundle:(NSBundle *)bundle
{
	if( (self = [super init]) )
	{
        NSNib *nib = [[[NSNib alloc] initWithNibNamed: @"CMRSegToolsPreferencePanel" bundle:[NSBundle bundleForClass:[self class]]] autorelease];
        [nib instantiateWithOwner:self topLevelObjects:NULL];
		
		[self setMainView:self.preferenceView];
		[self mainViewDidLoad];
	}
	
	return self;
}

- (void) mainViewDidLoad
{
    [self.filtersTable registerForDraggedTypes:@[CMRT1FilterType]];
//    self.filters.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES] ];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editingDidEnd:) name:NSControlTextDidEndEditingNotification object:nil]; // required to save value edited in table, otherwise not saved in NSUserDefaults
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
//    [preferenceView release];
    [super dealloc];
}

- (void) willUnselect
{
    [[[self mainView] window] makeFirstResponder: nil];
}

- (IBAction)updateColors:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:CMRSegToolsColorsDidUpdateNotification object:self];
}

- (IBAction)dummyType:(id)sender {
//    [[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:@"CMRT1PreprocessingFilterType"];
}

- (IBAction)insertFilter:(id)sender {
    NSDictionary *obj = [NSMutableDictionary dictionary];
    [self.filters addObject:obj];
    //[self.filters insert:sender];
    [NSOperationQueue.mainQueue addOperationWithBlock:^{
        NSUInteger idx = [self.filters.arrangedObjects indexOfObject:obj];
        self.filters.selectionIndex = idx;
        [self.filtersTable editColumn:0 row:idx withEvent:nil select:NO];
    }];
}

- (id <NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    NSPasteboardItem *pboardItem = [[[NSPasteboardItem alloc] init] autorelease];
    [pboardItem setPropertyList:@(row) forType:CMRT1FilterType];
    return pboardItem;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    NSUInteger irow = [[info.draggingPasteboard propertyListForType:CMRT1FilterType] integerValue];
    if (dropOperation == NSTableViewDropOn)
        [tableView setDropRow:row dropOperation:NSTableViewDropAbove];
    if (row == irow || row == irow+1)
        return NSDragOperationNone;
    return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    NSUInteger irow = [[info.draggingPasteboard propertyListForType:CMRT1FilterType] integerValue];
    
    if (row == irow || row == irow+1)
        return NO;
    
    id s = self.filters.selectedObjects;
    
    [self.filters insertObject:self.filters.arrangedObjects[irow] atArrangedObjectIndex:row];
    
    if (row < irow) ++irow;
    [self.filters removeObjectAtArrangedObjectIndex:irow];
    
    self.filters.selectedObjects = s;
    
    return YES;
}

- (void)editingDidEnd:(NSNotification *)notification { // called for NSControlTextDidEndEditingNotification events on ALL objects
    // is this a filters table NSTextField edit?
    BOOL isFilterEditor = NO;
    for (NSView *view = notification.object; view && !isFilterEditor; view = view.superview)
        if (view == self.filtersTable)
            isFilterEditor = YES;
    
    if (!isFilterEditor) // if it's not, don't act
        return;
    
    // this fixes the text field editor value not being stored to NSUserDefaults
    
    [[NSUserDefaults standardUserDefaults] setObject:self.filters.content forKey:@"CMRT1PreprocessingFilters"];
}

@end
