
#import <Cocoa/Cocoa.h>

#import "BaseProjectSettingsWindowController.h"


@interface CompilationSettingsWindowController : BaseProjectSettingsWindowController

@property (assign) IBOutlet NSPopUpButton *rubyVersionsPopUpButton;

@property (assign) IBOutlet NSTabView *tabView;
@property (assign) IBOutlet NSView *compilerSettingsTabView;
@property (assign) IBOutlet NSTableView *pathTableView;
@property (assign) IBOutlet NSButton *chooseFolderButton;

- (IBAction)chooseOutputFileName:(id)sender;

@end
