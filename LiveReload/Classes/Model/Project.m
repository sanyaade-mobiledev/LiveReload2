
#import "Project.h"
#import "FSMonitor.h"
#import "FSTreeFilter.h"
#import "FSTree.h"
#import "CommunicationController.h"
#import "Preferences.h"
#import "PluginManager.h"
#import "Compiler.h"
#import "CompilationOptions.h"


#define PathKey @"path"

NSString *ProjectDidDetectChangeNotification = @"ProjectDidDetectChangeNotification";



@interface Project () <FSMonitorDelegate>

- (void)updateFilter;
- (void)reconsiderMonitoringNecessity;

@end


@implementation Project

@synthesize path=_path;


#pragma mark -
#pragma mark Init/dealloc

- (void)initializeMonitoring {
    _monitor = [[FSMonitor alloc] initWithPath:_path];
    _monitor.delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFilter) name:PreferencesFilterSettingsChangedNotification object:nil];
    [self updateFilter];

    _compilerOptions = [[NSMutableDictionary alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reconsiderMonitoringNecessity) name:CompilationOptionsEnabledChangedNotification object:nil];
    [self reconsiderMonitoringNecessity];
}

- (id)initWithPath:(NSString *)path {
    if ((self = [super init])) {
        _path = [path copy];
        [self initializeMonitoring];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_path release], _path = nil;
    [_monitor release], _monitor = nil;
    [super dealloc];
}


#pragma mark - Displaying

- (NSString *)displayPath {
    return [_path stringByAbbreviatingWithTildeInPath];
}


#pragma mark - Filtering

- (void)updateFilter {
    _monitor.filter.ignoreHiddenFiles = YES;
    _monitor.filter.enabledExtensions = [Preferences sharedPreferences].allExtensions;
    _monitor.filter.excludedNames = [Preferences sharedPreferences].excludedNames;
    [_monitor filterUpdated];
}


#pragma mark -
#pragma mark Persistence

- (id)initWithMemento:(NSDictionary *)memento {
    if ((self = [super init])) {
        _path = [[memento objectForKey:PathKey] copy];
        [self initializeMonitoring];
    }
    return self;
}

- (NSDictionary *)memento {
    return [NSDictionary dictionaryWithObjectsAndKeys:_path, PathKey, nil];
}


#pragma mark -
#pragma mark File System Monitoring

- (BOOL)areAnyCompilersEnabled {
    for (CompilationOptions *options in [_compilerOptions allValues]) {
        if (options.enabled) {
            return YES;
        }
    }
    return NO;
}

- (void)reconsiderMonitoringNecessity {
    BOOL necessary = _clientsConnected || [self areAnyCompilersEnabled];
    if (necessary != _monitor.running) {
        NSLog(@"Monitoring %@ for project %@", (necessary ? @"actived" : @"deactivated"), _path);
        _monitor.running = necessary;
    }
}

- (BOOL)isMonitoringEnabled {
    return _clientsConnected;
}

- (void)setMonitoringEnabled:(BOOL)shouldMonitor {
    _clientsConnected = shouldMonitor;
    [self reconsiderMonitoringNecessity];
}

- (void)fileSystemMonitor:(FSMonitor *)monitor detectedChangeAtPathes:(NSSet *)pathes {
    NSMutableSet *filtered = [NSMutableSet setWithCapacity:[pathes count]];
    for (NSString *path in pathes) {
        Compiler *compiler = [[PluginManager sharedPluginManager] compilerForExtension:[path pathExtension]];
        if (compiler) {
            NSString *derivedName = [compiler derivedNameForFile:path];
            NSString *derivedPath = [_monitor.tree pathOfFileNamed:derivedName];
            if (derivedPath) {
                [compiler compile:path into:derivedPath];
            }
        } else {
            [filtered addObject:path];
        }
    }
    if ([filtered count] == 0) {
        return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:ProjectDidDetectChangeNotification object:self];
    [[CommunicationController sharedCommunicationController] broadcastChangedPathes:filtered inProject:self];
}

- (FSTree *)tree {
    return _monitor.tree;
}


#pragma mark - Options

- (CompilationOptions *)optionsForCompiler:(Compiler *)compiler create:(BOOL)create {
    NSString *uniqueId = compiler.uniqueId;
    CompilationOptions *options = [_compilerOptions objectForKey:uniqueId];
    if (options == nil && create) {
        options = [[CompilationOptions alloc] initWithCompiler:compiler dictionary:nil];
        [_compilerOptions setObject:options forKey:uniqueId];
    }
    return options;
}


@end
