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
 Name        : CMRSegTools Activation Code Controller.
 
 Description : Controller for the Activation Code window.
 
 Author      : William A. Romero R. <romero@creatis.insa-lyon.fr>
                                    <contact@waromero.com>
 
 CREATIS
 Copyright (C) 2014
 
 You should have received a copy  of the CMRSegTools license along with this
 program. Further information:
 
 http://www.creatis.insa-lyon.fr/
 
 -----------------------------------------------------------------------------
 */

#import "CMRSegToolsActivationCodeWindowController.h"
#import "CMRSegTools.h"
#import "NSString+Utils.h"

@interface CMRSegToolsActivationCodeWindowController ()

@end

@implementation CMRSegToolsActivationCodeWindowController


/**
 * Default init.
 */
- (id) init
{
    self = [super initWithWindowNibName:@"CMRSegToolsActivationCodeWindow" owner:self];
    return self;
}


- (void)dealloc
{
    [super dealloc];
}


- (IBAction) validateActivationCode:(id)sender
{
    NSMutableString *informativeText = [NSMutableString stringWithString:@""];
    
	NSString* serialNumber = [activationCodeField stringValue];
	
	if ([CMRSegTools verifySerialNumber:[serialNumber getSerialNumberBytes]])
    {
		[activationCodeField selectText:self];
        [[NSUserDefaults standardUserDefaults] setObject:serialNumber forKey:@"CMRSegToolSerialNumber"];
        [informativeText setString:@"CMRSegTools has been activated.\n Start CMRSegTools once again."];
		
	} else
    {
        [informativeText setString:@"Activation Code is invalid."];
    }
    
    NSBeep();
    
    NSAlert *activationAlert = [NSAlert alertWithMessageText:@"CMRSegTools Activation Code"
                                               defaultButton:nil
                                             alternateButton:nil
                                                 otherButton:nil
                                   informativeTextWithFormat:@"%@", informativeText];
    [activationAlert setAlertStyle:NSCriticalAlertStyle];
    [activationAlert runModal];
    
    [self close];
    [self autorelease];
}


- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}


- (IBAction) showWindow:(id)sender
{
    [super showWindow:sender];
    [ [self window] setTitle:@"CMRSegTools Activation Code"];
}


- (void) windowWillClose:(NSNotification *)notification
{
    [self autorelease]; // from the retain in init
}

@end
