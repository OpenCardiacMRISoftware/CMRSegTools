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
//  CMRSTActivityButton.m
//  CMRSegTools
//
//  Created by Alessandro Volz on 7/7/15.
//  Copyright (c) 2015 Spaltenstein Natural Image. All rights reserved.
//

#import "CMRActivityButton.h"

@implementation CMRActivityButton

@synthesize progressIndicator = _progressIndicator;

- (id)initWithFrame:(NSRect)frameRect {
    if ((self = [super initWithFrame:frameRect])) {
        [self initialize:CMRActivityButton.class];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self initialize:CMRActivityButton.class];
    }
    
    return self;
}

- (void)initialize:(Class)class {
    if (class == CMRActivityButton.class) {
        [self addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:CMRActivityButton.class];
    }
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"state" context:CMRActivityButton.class];
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != CMRActivityButton.class)
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    
    if ([keyPath isEqualToString:@"state"]) {
        if (/*self.buttonType == NSPushOnPushOffButton && */[change[NSKeyValueChangeNewKey] integerValue] == NSOffState)
            [self.progressIndicator stopAnimation:self];
    }
}

@end
