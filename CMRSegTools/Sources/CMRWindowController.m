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
//  CMRWindowController.m
//  CMRSegTools
//
//  Created by Alessandro Volz on 5/10/16.
//  Copyright © 2016 volz io. All rights reserved.
//

#import "CMRWindowController.h"
#import <objc/runtime.h>

@implementation CMRWindowController

+ (Class)NSWindowClass {
    return NSWindow.class;
}

+ (NSRect)contentRect {
    return [NSScreen.mainScreen visibleFrame];
}

+ (NSUInteger)styleMask {
    return NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask;
}

+ (NSWindow *)window {
    return [[[self.class.NSWindowClass alloc] initWithContentRect:self.class.contentRect styleMask:self.class.styleMask backing:NSBackingStoreBuffered defer:NO] autorelease];
}

- (instancetype)initWithContentViewController:(NSViewController *)contentViewController {
    if (!(self = [super initWithWindow:[self.class window]]))
        return nil;
    
    self.contentViewController = contentViewController;
    [self addObserver:self forKeyPath:@"window.contentView.fittingSize" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:CMRWindowController.class];
    
    return self;
}

+ (BOOL)NSWindowControllerContentViewController {
    return (class_getInstanceMethod(NSViewController.class, @selector(contentViewController)) != nil);
}

- (NSViewController *)contentViewController {
    if ([self.class NSWindowControllerContentViewController])
        return [super contentViewController];
    return objc_getAssociatedObject(self, @selector(contentViewController));
}

- (void)setContentViewController:(NSViewController *)contentViewController {
    [self.window setContentView:contentViewController.view];
    if ([self.class NSWindowControllerContentViewController])
        [super setContentViewController:contentViewController];
    else objc_setAssociatedObject(self, @selector(contentViewController), contentViewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)dealloc {
#if DEBUG == 1
    NSLog(@"Info: deallocating %@ 0x%lx (CMRWindowController)", self.className, (unsigned long)self);
#endif
    
    [self removeObserver:self forKeyPath:@"window.contentView.fittingSize" context:CMRWindowController.class];
    
    if (self.contentViewController)
        self.contentViewController = nil;
    
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != CMRWindowController.class)
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    
    if ([keyPath isEqualToString:@"window.contentView.fittingSize"]) {
        if ([change[NSKeyValueChangeNewKey] isKindOfClass:NSValue.class]) {
            NSSize size = [change[NSKeyValueChangeNewKey] sizeValue];
            if (size.width > 0 && size.height > 0)
                [self.window setFrame:[self.window frameRectForContentRect:NSMakeRect(self.window.frame.origin.x, self.window.frame.origin.y, size.width, size.height)] display:YES animate:YES]; // [self.window setContentSize:size];
        }
    }
}

- (void)observeWindowWillClose:(NSNotification *)notification {
    self.contentViewController = nil;
}

@end
