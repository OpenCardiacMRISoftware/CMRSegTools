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
//  CMRImageButton.m
//  CMR
//
//  Created by Alessandro Volz on 1/14/15.
//
//

#import "CMRImageButton.h"

static const CGFloat CMRImageButtonAlpha = .66;
static const CGFloat CMRImageButtonHoverAlpha = .8;
static const CGFloat CMRImageButtonDownAlpha = 1;

@implementation CMRImageButton

@synthesize tracking = _tracking;

- (id)initWithFrame:(NSRect)frameRect {
    if ((self = [super initWithFrame:frameRect])) {
        [self initialize:CMRImageButton.class];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self initialize:CMRImageButton.class];
    }
    
    return self;
}

- (void)initialize:(Class)class {
    if (class == CMRImageButton.class) {
        [self.cell setControlSize:NSSmallControlSize];
        [self.cell setHighlightsBy:NSNoCellMask];
        [self.cell setShowsStateBy:NSNoCellMask];
        self.bordered = NO;
        self.autoresizingMask = NSViewMinXMargin+NSViewMinYMargin;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.imagePosition = NSImageOnly;
        self.alphaValue = CMRImageButtonAlpha;
        self.tracking = YES;
    }
}

- (void)setTracking:(BOOL)tracking {
    _tracking = tracking;
    [self updateTrackingAreas];
}

- (void)updateTrackingAreas {
    if (self.isTracking) {
        if (_trackingArea && !NSEqualRects(self.bounds, _trackingArea.rect)) {
            [self removeTrackingArea:_trackingArea];
            _trackingArea = nil;
        }
        if (!_trackingArea)
            [self addTrackingArea:(_trackingArea = [[[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways owner:self userInfo:nil] autorelease])];
    }
}

- (void)mouseEntered:(NSEvent*)theEvent {
    self.alphaValue = CMRImageButtonHoverAlpha;
}

- (void)mouseExited:(NSEvent*)theEvent {
    self.alphaValue = CMRImageButtonAlpha;
}

- (void)mouseDown:(NSEvent*)theEvent {
    self.alphaValue = CMRImageButtonDownAlpha;
    if (!self.menu)
        return [super mouseDown:theEvent];
    [NSMenu popUpContextMenu:self.menu withEvent:theEvent forView:self withFont:[NSFont menuFontOfSize:[NSFont smallSystemFontSize]]];
}

@end
