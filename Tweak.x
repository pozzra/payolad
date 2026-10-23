#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// Rxaa is a UI-only debug overlay. It intentionally contains no game hooks,
// memory access, aimbot, ESP, or offset code.

static UIWindow *gOverlayWindow = nil;
static UIWindow *gButtonWindow = nil;
static UIButton *gFloatButton = nil;
static UINavigationController *gMenuNav = nil;
static UITapGestureRecognizer *gOpenGesture = nil;
static UIWindow *gGestureWindow = nil;
static UIWindow *gPreviousKeyWindow = nil;
static int gInstallAttempts = 0;
static BOOL gInstallRetryScheduled = NO;
static BOOL gUsingLegacyWindows = NO;
static BOOL gMenuDismissing = NO;

static CGFloat const kRXAAFloatButtonSize = 52.0;
static CGFloat const kRXAAFloatButtonMargin = 10.0;
static NSString * const kRXAAFloatCenterXKey = @"rxaa.float.centerX";
static NSString * const kRXAAFloatCenterYKey = @"rxaa.float.centerY";
static CGPoint gButtonPanStartCenter;
static CGPoint gButtonPanStartPoint;

static void RAACHEATAttachWindowToScene(void);
static void RAACHEATTryInstall(void);
static void RAACHEATEnsureOverlayVisible(void);
static void RAACHEATScheduleInstallRetry(void);
static UIWindowScene *RAACHEATActiveWindowScene(void);
static UIWindow *RAACHEATHostWindow(UIWindowScene *scene);

@interface RAACHEATPassThroughView : UIView
@end

@implementation RAACHEATPassThroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}
@end

static UIColor *RXAAGreen(void) {
    return [UIColor colorWithRed:0.31 green:0.94 blue:0.65 alpha:1.0];
}

static UIColor *RXAABackground(void) {
    return [UIColor blackColor];
}

static NSString *RAACHEATResourcePath(NSString *name) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *bases = @[
        @"/var/jb/Library/Application Support/RAACHEATMenuDebug",
        @"/private/var/jb/Library/Application Support/RAACHEATMenuDebug",
        @"/Library/Application Support/RAACHEATMenuDebug"
    ];
    for (NSString *base in bases) {
        NSString *path = [base stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:path]) {
            return path;
        }
    }
    return nil;
}

static NSString *RAACHEATCatalogPath(void) {
    return RAACHEATResourcePath(@"index.html");
}

typedef struct {
    const char *label;
    const char *category;
    const char *kind;
} RXAAEmbeddedFeature;

static const RXAAEmbeddedFeature kRXAAEmbeddedFeatures[] = {
    {"AIMLOCK 100%", "aimbot", "toggle"},
    {"AIMBOT 360", "aimbot", "toggle"},
    {"AIMBOT 180", "aimbot", "toggle"},
    {"WALLHACK", "visuals", "toggle"},
    {"NO RECOIL 100%", "memory", "toggle"},
    {"SPEED", "memory", "toggle"},
    {"SPEED EPIC", "memory", "toggle"},
    {"MOD HACK", "settings", "label"},
    {"AimBot / AimLock Enable", "aimbot", "toggle"},
    {"Aim FOV Radius", "aimbot", "slider"},
    {"Aim Lock Distance", "aimbot", "slider"},
    {"Aim Smooth", "aimbot", "slider"},
    {"Aim.AutoShoot", "aimbot", "config-key"},
    {"Aim.AutoShootDistance", "aimbot", "config-key"},
    {"Aim.Cross", "aimbot", "config-key"},
    {"Aim.Enable", "aimbot", "config-key"},
    {"Aim.Fov", "aimbot", "config-key"},
    {"Aim.IgnoreBot", "aimbot", "config-key"},
    {"Aim.IgnoreKnocked", "aimbot", "config-key"},
    {"Aim.InstantAim", "aimbot", "config-key"},
    {"Aim.MaxDistance", "aimbot", "config-key"},
    {"Aim.Power", "aimbot", "config-key"},
    {"Aim.Silent360", "aimbot", "config-key"},
    {"Aim.SilentAim", "aimbot", "config-key"},
    {"Aim.SilentDistance", "aimbot", "config-key"},
    {"Aim.Smooth", "aimbot", "config-key"},
    {"Aim.TargetBone", "aimbot", "config-key"},
    {"Aim.TeamCheck", "aimbot", "config-key"},
    {"Aim.Trigger", "aimbot", "config-key"},
    {"Aim.VisCheck", "aimbot", "config-key"},
    {"Aimbot", "aimbot", "label"},
    {"AUTOLOCK // RADAR TRACK  ", "aimbot", "label"},
    {"Draw Aim FOV Circle", "aimbot", "toggle"},
    {"Esp Bone", "aimbot", "label"},
    {"Follow Hardness (Power)", "aimbot", "label"},
    {"Ignore Knocked", "aimbot", "toggle"},
    {"Instant AimLock (Direct Snap)", "aimbot", "toggle"},
    {"QUANTUM AIM ", "aimbot", "label"},
    {"Red tracers, white bones, yellow labels and health above the head.", "aimbot", "label"},
    {"Settings.Unlock120FPS", "aimbot", "config-key"},
    {"Silent 360", "aimbot", "toggle"},
    {"Silent Aim (Magic Bullet)", "aimbot", "toggle"},
    {"Silent Aim Distance", "aimbot", "slider"},
    {"Target Bone", "aimbot", "combo"},
    {"TARGET FILTERS", "aimbot", "label"},
    {"Teammates excluded (always)", "aimbot", "label"},
    {"Trigger Condition", "aimbot", "combo"},
    {"Unlock 120 FPS", "aimbot", "label"},
    {"Video palette: white player tracers, green bot tracers, red/green bones and colored name plates.", "aimbot", "label"},
    {"Box Color", "visuals", "label"},
    {"CYBER ESP ", "visuals", "label"},
    {"Distance", "visuals", "label"},
    {"Esp Box", "visuals", "label"},
    {"Esp Count", "visuals", "label"},
    {"Esp Distance", "visuals", "label"},
    {"Esp Health", "visuals", "label"},
    {"ESP Layout", "visuals", "label"},
    {"Esp Line", "visuals", "label"},
    {"Esp Name", "visuals", "label"},
    {"ESP.Alert", "visuals", "config-key"},
    {"ESP.Bot", "visuals", "config-key"},
    {"ESP.Box", "visuals", "config-key"},
    {"ESP.BoxColor.w", "visuals", "config-key"},
    {"ESP.BoxColor.x", "visuals", "config-key"},
    {"ESP.BoxColor.y", "visuals", "config-key"},
    {"ESP.BoxColor.z", "visuals", "config-key"},
    {"ESP.CrownArrows", "visuals", "config-key"},
    {"ESP.CrownRing", "visuals", "config-key"},
    {"ESP.CrownWeapons", "visuals", "config-key"},
    {"ESP.Distance", "visuals", "config-key"},
    {"ESP.EnemyOnly", "visuals", "config-key"},
    {"ESP.Knocked", "visuals", "config-key"},
    {"ESP.Line", "visuals", "config-key"},
    {"ESP.LineBelow", "visuals", "config-key"},
    {"ESP.LineColor.w", "visuals", "config-key"},
    {"ESP.LineColor.x", "visuals", "config-key"},
    {"ESP.LineColor.y", "visuals", "config-key"},
    {"ESP.LineColor.z", "visuals", "config-key"},
    {"ESP.LinePosition", "visuals", "config-key"},
    {"ESP.LineThickness", "visuals", "config-key"},
    {"ESP.MaxDistance", "visuals", "config-key"},
    {"ESP.Name", "visuals", "config-key"},
    {"ESP.Skeleton", "visuals", "config-key"},
    {"ESP.SkeletonColor.w", "visuals", "config-key"},
    {"ESP.SkeletonColor.x", "visuals", "config-key"},
    {"ESP.SkeletonColor.y", "visuals", "config-key"},
    {"ESP.SkeletonColor.z", "visuals", "config-key"},
    {"ESP.SkeletonDebug", "visuals", "config-key"},
    {"ESP.Vehicle", "visuals", "config-key"},
    {"Hide ESP (Screen & Recording)", "visuals", "label"},
    {"Line Color", "visuals", "label"},
    {"Line Position", "visuals", "label"},
    {"RADAR FX", "visuals", "label"},
    {"Skeleton Color", "visuals", "label"},
    {"Style Box", "visuals", "label"},
    {"Vehicle Esp", "visuals", "label"},
    {"Visuals", "visuals", "label"},
    {"Memory", "memory", "label"},
    {"Memory Engine", "memory", "label"},
    {"RegionSwitchButton", "memory", "label"},
    {"SELECT SEARCH REGION", "memory", "label"},
    {"Speed Multiplier", "memory", "label"},
    {"Speed.Multiplier", "memory", "config-key"},
    {"CONFIGURATION", "settings", "label"},
    {"HUD CONFIG & FX ", "settings", "label"},
    {"LOAD CONFIG", "settings", "label"},
    {"MenuHeaderClose", "settings", "label"},
    {"Package", "settings", "label"},
    {"Runtime", "settings", "label"},
    {"SAVE PRESET", "settings", "label"},
    {"Settings", "settings", "label"},
    {"Settings.HideRecording", "settings", "config-key"},
    {"Choose the optimal scanning region for your device and game version:", "help", "help"},
    {"Note: You can switch regions anytime from the top bar.", "help", "help"},
    {"Select the game memory search region for this session.", "help", "help"},
    {"Tap to cycle search region: OTHER -> ANONYMOUS -> C_ALLOC", "help", "help"},
};

static NSArray<NSDictionary *> *RXAAEmbeddedCatalogFeatures(void) {
    NSUInteger count = (NSUInteger)(sizeof(kRXAAEmbeddedFeatures) / sizeof(kRXAAEmbeddedFeatures[0]));
    NSMutableArray<NSDictionary *> *result = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        RXAAEmbeddedFeature feature = kRXAAEmbeddedFeatures[i];
        [result addObject:@{
            @"label": [NSString stringWithUTF8String:feature.label],
            @"category": [NSString stringWithUTF8String:feature.category],
            @"kind": [NSString stringWithUTF8String:feature.kind]
        }];
    }
    return result;
}

static NSArray<NSString *> *RXAACatalogCategories(void) {
    return @[@"aimbot", @"visuals", @"memory", @"settings", @"help"];
}

static NSArray<NSString *> *RXAACatalogAllCategories(void) {
    return @[@"aimbot", @"visuals", @"memory", @"settings", @"help",
             @"ui", @"ui-id", @"runtime", @"path", @"format"];
}

static NSString *RXAACatalogCategoryDisplayName(NSString *category) {
    if ([category isEqualToString:@"aimbot"]) {
        return @"Aimbot & Combat";
    } else if ([category isEqualToString:@"visuals"]) {
        return @"Cyber ESP & Visuals";
    } else if ([category isEqualToString:@"memory"]) {
        return @"Memory & Movement";
    } else if ([category isEqualToString:@"settings"]) {
        return @"Settings & Config";
    } else if ([category isEqualToString:@"help"]) {
        return @"Help & Notes";
    } else if ([category isEqualToString:@"ui"]) {
        return @"UI Strings";
    } else if ([category isEqualToString:@"ui-id"]) {
        return @"UI Identifiers";
    } else if ([category isEqualToString:@"runtime"]) {
        return @"Runtime Diagnostics";
    } else if ([category isEqualToString:@"path"]) {
        return @"Game Paths";
    } else if ([category isEqualToString:@"format"]) {
        return @"Format Strings";
    }
    return category ? [category capitalizedString] : @"Catalog";
}

static NSArray<NSDictionary *> *RXAACatalogLoadItemsInCategories(NSArray<NSString *> *categories) {
    NSString *path = RAACHEATResourcePath(@"menu_catalog.json");
    NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
    id root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSArray *items = nil;
    if ([root isKindOfClass:[NSDictionary class]]) {
        id value = ((NSDictionary *)root)[@"items"];
        if ([value isKindOfClass:[NSArray class]]) {
            items = (NSArray *)value;
        }
    }

    NSSet<NSString *> *wanted = [NSSet setWithArray:categories];
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    for (id item in items) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *entry = (NSDictionary *)item;
        NSString *category = entry[@"category"];
        NSString *label = entry[@"label"];
        if (![category isKindOfClass:[NSString class]] ||
            ![label isKindOfClass:[NSString class]] ||
            ![wanted containsObject:category]) {
            continue;
        }
        [result addObject:entry];
    }
    if (result.count == 0) {
        NSLog(@"[Rxaa] catalog JSON unavailable at %@; using embedded catalog", path);
        return RXAAEmbeddedCatalogFeatures();
    }
    NSLog(@"[Rxaa] loaded %lu catalog entries from %@",
          (unsigned long)result.count, path);
    return [result copy];
}

static NSArray<NSDictionary *> *RXAACatalogFeatures(void) {
    static NSArray<NSDictionary *> *features = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        features = RXAACatalogLoadItemsInCategories(RXAACatalogCategories());
    });
    return features ? features : @[];
}

static NSArray<NSDictionary *> *RXAACatalogAllFeatures(void) {
    static NSArray<NSDictionary *> *features = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        features = RXAACatalogLoadItemsInCategories(RXAACatalogAllCategories());
    });
    return features ? features : @[];
}

static NSArray<NSDictionary *> *RXAACatalogFilterByCategory(NSArray<NSDictionary *> *items,
                                                            NSString *category) {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    for (NSDictionary *item in items) {
        if ([item[@"category"] isEqualToString:category]) {
            [result addObject:item];
        }
    }
    return result;
}

static NSArray<NSDictionary *> *RXAACatalogFeaturesForCategory(NSString *category) {
    return RXAACatalogFilterByCategory(RXAACatalogFeatures(), category);
}

static NSArray<NSDictionary *> *RXAACatalogAllFeaturesForCategory(NSString *category) {
    return RXAACatalogFilterByCategory(RXAACatalogAllFeatures(), category);
}

static NSString *RXAACatalogFeatureKey(NSDictionary *item) {
    NSString *category = item[@"category"];
    NSString *label = item[@"label"];
    if (!category) {
        category = @"feature";
    }
    if (!label) {
        label = @"unknown";
    }
    return [NSString stringWithFormat:@"rxaa.catalog.%@.%@", category, label];
}

static BOOL RXAACatalogFeatureIsActionable(NSDictionary *item) {
    NSString *kind = item[@"kind"];
    return [kind isEqualToString:@"toggle"] ||
           [kind isEqualToString:@"slider"] ||
           [kind isEqualToString:@"combo"] ||
           [kind isEqualToString:@"config-key"];
}

static NSUInteger RXAACatalogActionableCount(NSArray<NSDictionary *> *items) {
    NSUInteger count = 0;
    for (NSDictionary *item in items) {
        if (RXAACatalogFeatureIsActionable(item)) {
            count++;
        }
    }
    return count;
}

static NSArray<NSDictionary *> *RXAASidebarCatalogRows(void) {
    static NSArray<NSDictionary *> *rows = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
        for (NSString *category in RXAACatalogCategories()) {
            NSUInteger count = [RXAACatalogFeaturesForCategory(category) count];
            [result addObject:@{
                @"key": category,
                @"title": RXAACatalogCategoryDisplayName(category),
                @"subtitle": [NSString stringWithFormat:@"%lu entries", (unsigned long)count]
            }];
        }
        rows = [result copy];
    });
    return rows ? rows : @[];
}

static NSArray<NSDictionary *> *RXAAMenuToolRows(void) {
    static NSArray<NSDictionary *> *rows = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSUInteger allCount = [RXAACatalogAllFeatures() count];
        NSUInteger actionableCount = RXAACatalogActionableCount(RXAACatalogAllFeatures());
        rows = @[
            @{@"action": @"apply-all",
              @"title": @"Apply All (Demo)",
              @"subtitle": [NSString stringWithFormat:@"Turn %lu catalog switches ON",
                            (unsigned long)actionableCount]},
            @{@"action": @"reset-all",
              @"title": @"Reset All (Demo)",
              @"subtitle": [NSString stringWithFormat:@"Turn %lu catalog switches OFF",
                            (unsigned long)actionableCount]},
            @{@"action": @"get-code",
              @"title": @"Get Code (Offline Catalog)",
              @"subtitle": @"Browse addresses, xrefs and ARM64 snippets"},
            @{@"action": @"all-features",
              @"title": @"Full Catalog",
              @"subtitle": [NSString stringWithFormat:@"%lu entries across all categories",
                            (unsigned long)allCount]},
            @{@"action": @"python",
              @"title": @"Python Engine (mod_menu.py)",
              @"subtitle": @"CLI & config generator in Application Support"},
            @{@"action": @"telegram",
              @"title": @"Telegram: @kun_amra",
              @"subtitle": @"Tap to open the official channel"},
            @{@"action": @"repair-overlay",
              @"title": @"Repair / Reattach Overlay",
              @"subtitle": @"Reattach Rxaa to current game window & scene"},
            @{@"action": @"game-status",
              @"title": @"Game Status & Diagnostics",
              @"subtitle": @"Bundle, scenes, windows, overlay state, ros.dylib"},
            @{@"action": @"about",
              @"title": @"About Rxaa",
              @"subtitle": @"UI-only debug build | no game hooks"}
        ];
    });
    return rows ? rows : @[];
}

typedef NS_ENUM(NSInteger, RXAAMenuDetailMode) {
    RXAAMenuDetailModeCatalog = 0,
    RXAAMenuDetailModeTools = 1
};

@interface RXAAMenuViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *sidebarTableView;
@property (nonatomic, strong) UITableView *detailTableView;
@property (nonatomic, strong) UIView *dividerView;
@property (nonatomic, copy) NSString *activeCategory;
@property (nonatomic, assign) RXAAMenuDetailMode detailMode;
- (void)configureNavigationBar;
- (void)selectActiveSidebarRow;
- (void)closeMenu;
- (UITableViewCell *)sidebarCellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)detailCellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)catalogSwitchChanged:(UISwitch *)sender;
- (NSUInteger)setAllDemoSwitches:(BOOL)on;
- (void)showFeatureDetails:(NSDictionary *)item;
- (void)showPythonEngineInfo;
- (void)showAbout;
- (void)showDemoActionAlert:(BOOL)on count:(NSUInteger)count;
- (void)showRepairOverlayDiagnostics;
- (void)showGameStatusDiagnostics;
- (void)handleToolAction:(NSString *)action;
@end

@interface RXAACatalogFeatureViewController : UITableViewController
@property (nonatomic, assign) BOOL showsAllCategories;
@property (nonatomic, copy) NSArray<NSString *> *visibleCategories;
- (void)catalogSwitchChanged:(UISwitch *)sender;
- (NSArray<NSString *> *)catalogCategories;
- (NSArray<NSDictionary *> *)featuresForCategory:(NSString *)category;
@end

@interface RXAACatalogSwitch : UISwitch
@property (nonatomic, copy) NSString *featureKey;
@end

@interface RXAACatalogViewController : UIViewController <WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UILabel *errorLabel;
- (void)showCatalogError:(NSString *)message;
@end

@interface RAACHEATRootController : UIViewController <UIGestureRecognizerDelegate>
- (void)raacheatOpen;
@end

@interface RAACHEATButtonController : UIViewController
- (void)raacheatOpen;
- (void)raacheatPan:(UIPanGestureRecognizer *)pan;
@end

static BOOL RAACHEATIsRxaaWindow(UIWindow *window) {
    return window != nil && (window == gOverlayWindow || window == gButtonWindow);
}

static UIWindow *RAACHEATKeyWindowForScene(UIWindowScene *scene) {
    if (@available(iOS 13.0, *)) {
        if (scene) {
            for (UIWindow *window in scene.windows) {
                if (window.isKeyWindow && !RAACHEATIsRxaaWindow(window)) {
                    return window;
                }
            }
        }
        for (UIScene *connected in [UIApplication sharedApplication].connectedScenes) {
            if (![connected isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            for (UIWindow *window in ((UIWindowScene *)connected).windows) {
                if (window.isKeyWindow && !RAACHEATIsRxaaWindow(window)) {
                    return window;
                }
            }
        }
    }
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow && !RAACHEATIsRxaaWindow(window)) {
            return window;
        }
    }
    return nil;
}

static CGRect RAACHEATScreenBounds(void) {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = gOverlayWindow.windowScene;
        if (scene) {
            CGRect bounds = scene.coordinateSpace.bounds;
            if (!CGRectIsEmpty(bounds)) {
                return bounds;
            }
        }
    }
    return [UIScreen mainScreen].bounds;
}

static UIEdgeInsets RAACHEATScreenSafeInsets(void) {
    if (@available(iOS 11.0, *)) {
        UIWindow *key = RAACHEATKeyWindowForScene(nil);
        if (key && key != gOverlayWindow && key != gButtonWindow) {
            return key.safeAreaInsets;
        }
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window != gOverlayWindow && window != gButtonWindow && !window.hidden) {
                return window.safeAreaInsets;
            }
        }
    }
    return UIEdgeInsetsZero;
}

static CGPoint RAACHEATClampFloatButtonCenter(CGPoint center) {
    CGRect screen = RAACHEATScreenBounds();
    if (CGRectIsEmpty(screen)) {
        return center;
    }
    UIEdgeInsets insets = RAACHEATScreenSafeInsets();
    CGFloat half = kRXAAFloatButtonSize * 0.5;
    CGFloat minX = screen.origin.x + insets.left + kRXAAFloatButtonMargin + half;
    CGFloat maxX = screen.origin.x + screen.size.width - insets.right -
                   kRXAAFloatButtonMargin - half;
    CGFloat minY = screen.origin.y + insets.top + kRXAAFloatButtonMargin + half;
    CGFloat maxY = screen.origin.y + screen.size.height - insets.bottom -
                   kRXAAFloatButtonMargin - half;

    if (maxX < minX) {
        minX = maxX = CGRectGetMidX(screen);
    }
    if (maxY < minY) {
        minY = maxY = CGRectGetMidY(screen);
    }

    center.x = MAX(minX, MIN(maxX, center.x));
    center.y = MAX(minY, MIN(maxY, center.y));
    return center;
}

static void RAACHEATSaveFloatButtonPosition(void) {
    if (!gButtonWindow) {
        return;
    }
    CGRect screen = RAACHEATScreenBounds();
    if (CGRectIsEmpty(screen)) {
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat x = (gButtonWindow.center.x - screen.origin.x) / screen.size.width;
    CGFloat y = (gButtonWindow.center.y - screen.origin.y) / screen.size.height;
    [defaults setDouble:x forKey:kRXAAFloatCenterXKey];
    [defaults setDouble:y forKey:kRXAAFloatCenterYKey];
}

static void RAACHEATRestoreFloatButtonPosition(void) {
    if (!gButtonWindow) {
        return;
    }
    CGRect screen = RAACHEATScreenBounds();
    if (CGRectIsEmpty(screen)) {
        return;
    }

    UIEdgeInsets insets = RAACHEATScreenSafeInsets();
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *savedX = [defaults objectForKey:kRXAAFloatCenterXKey];
    NSNumber *savedY = [defaults objectForKey:kRXAAFloatCenterYKey];
    CGPoint center = CGPointZero;

    if (savedX && savedY) {
        center.x = screen.origin.x + (CGFloat)[savedX doubleValue] * screen.size.width;
        center.y = screen.origin.y + (CGFloat)[savedY doubleValue] * screen.size.height;
    } else {
        center.x = screen.origin.x + screen.size.width - insets.right -
                   kRXAAFloatButtonMargin - (kRXAAFloatButtonSize * 0.5);
        center.y = screen.origin.y + insets.top + kRXAAFloatButtonMargin + 92.0 +
                   (kRXAAFloatButtonSize * 0.5);
    }

    CGRect frame = gButtonWindow.frame;
    frame.size = CGSizeMake(kRXAAFloatButtonSize, kRXAAFloatButtonSize);
    gButtonWindow.frame = frame;
    UIView *buttonView = gButtonWindow.rootViewController.view;
    if (buttonView) {
        buttonView.frame = CGRectMake(0.0, 0.0,
                                      kRXAAFloatButtonSize, kRXAAFloatButtonSize);
        if (gFloatButton) {
            gFloatButton.frame = buttonView.bounds;
        }
    }
    gButtonWindow.center = RAACHEATClampFloatButtonCenter(center);
}

static void RAACHEATRestoreGameKeyWindow(void) {
    UIWindow *target = gPreviousKeyWindow;
    if (!target || RAACHEATIsRxaaWindow(target) || target.hidden) {
        target = nil;
    }

    if (@available(iOS 13.0, *)) {
        UIWindowScene *overlayScene = gOverlayWindow.windowScene;
        if (overlayScene && (!target || target.windowScene != overlayScene)) {
            for (UIWindow *window in overlayScene.windows) {
                if (!RAACHEATIsRxaaWindow(window) && !window.hidden) {
                    target = window;
                    break;
                }
            }
        }
    }

    if (!target) {
        target = RAACHEATKeyWindowForScene(nil);
        if (RAACHEATIsRxaaWindow(target) || target.hidden) {
            target = nil;
        }
    }
    if (!target) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (!RAACHEATIsRxaaWindow(window) && !window.hidden) {
                target = window;
                break;
            }
        }
    }
    if (target) {
        [target makeKeyWindow];
        NSLog(@"[Rxaa] game key window restored: %@", target);
    } else if (gOverlayWindow) {
        [gOverlayWindow resignKeyWindow];
        NSLog(@"[Rxaa] no game key window found; overlay resigned key");
    }
    gPreviousKeyWindow = nil;
}

static void RAACHEATRestorePreviousKeyWindow(void) {
    if (gOverlayWindow) {
        gOverlayWindow.hidden = YES;
    }
    if (gButtonWindow) {
        gButtonWindow.hidden = NO;
        gButtonWindow.windowLevel = UIWindowLevelAlert + 1001.0;
        RAACHEATRestoreFloatButtonPosition();
    }
    RAACHEATRestoreGameKeyWindow();
}

static void RAACHEATDismissMenuForResignation(void) {
    UINavigationController *nav = gMenuNav;
    gMenuNav = nil;
    gMenuDismissing = YES;

    void (^finish)(void) = ^{
        gMenuDismissing = NO;
        RAACHEATRestoreGameKeyWindow();
        if (gOverlayWindow) {
            UIViewController *root = gOverlayWindow.rootViewController;
            if (root.presentedViewController) {
                [root dismissViewControllerAnimated:NO completion:nil];
            }
            gOverlayWindow.hidden = YES;
        }
        if (gButtonWindow) {
            gButtonWindow.hidden = YES;
        }
    };

    if (!nav) {
        gMenuDismissing = NO;
        if (gOverlayWindow) {
            gOverlayWindow.hidden = YES;
        }
        if (gButtonWindow) {
            gButtonWindow.hidden = YES;
        }
        return;
    }

    NSLog(@"[Rxaa] app resigned active; closing menu");
    UIViewController *presenter = nav.presentingViewController;
    if (!presenter && gOverlayWindow) {
        presenter = gOverlayWindow.rootViewController;
    }
    if (presenter) {
        [presenter dismissViewControllerAnimated:NO completion:finish];
    } else {
        finish();
    }
}

static void RAACHEATRefreshOverlayBounds(void) {
    if (!gOverlayWindow) {
        return;
    }

    CGRect bounds = CGRectZero;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = gOverlayWindow.windowScene;
        if (!scene) {
            scene = RAACHEATActiveWindowScene();
        }
        if (scene) {
            bounds = scene.coordinateSpace.bounds;
        }
    }
    if (CGRectIsEmpty(bounds)) {
        UIWindow *host = RAACHEATHostWindow(gOverlayWindow.windowScene);
        if (host) {
            bounds = host.bounds;
        }
    }
    if (CGRectIsEmpty(bounds)) {
        bounds = [UIScreen mainScreen].bounds;
    }
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    gOverlayWindow.frame = bounds;
    UIViewController *root = gOverlayWindow.rootViewController;
    root.view.frame = gOverlayWindow.bounds;
    if (gButtonWindow) {
        RAACHEATRestoreFloatButtonPosition();
    }
}

@interface RXAANavigationController : UINavigationController
@end

@implementation RXAANavigationController
- (UIViewController *)childForStatusBarStyle {
    return self.topViewController;
}
- (UIViewController *)childForStatusBarHidden {
    return self.topViewController;
}
@end

static void RAACHEATOpenPanel(void) {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        NSLog(@"[Rxaa] open ignored: app is not active");
        return;
    }
    if (!gOverlayWindow) {
        NSLog(@"[Rxaa] open requested before overlay install; retrying install");
        RAACHEATTryInstall();
        return;
    }

    UIViewController *root = gOverlayWindow.rootViewController;
    if (!root) {
        NSLog(@"[Rxaa] open ignored: overlay root is nil");
        return;
    }

    if (gMenuNav) {
        if (root.presentedViewController == gMenuNav ||
            gMenuNav.presentingViewController == root) {
            NSLog(@"[Rxaa] open ignored: menu already presented");
            return;
        }
        gMenuNav = nil;
    }

    if (root.presentedViewController) {
        // A menu left presented across a resign/activate cycle used to block every
        // later open. Dismiss the stale controller first, then retry once.
        UIViewController *stale = root.presentedViewController;
        NSLog(@"[Rxaa] dismissing stale presentation before open: %@", stale);
        gMenuDismissing = YES;
        [root dismissViewControllerAnimated:NO completion:^{
            gMenuDismissing = NO;
            if (gOverlayWindow.rootViewController.presentedViewController == nil) {
                RAACHEATOpenPanel();
            } else {
                NSLog(@"[Rxaa] stale presentation did not dismiss");
            }
        }];
        return;
    }

    NSLog(@"[Rxaa] opening menu");
    gMenuDismissing = NO;
    RAACHEATAttachWindowToScene();
    RAACHEATRefreshOverlayBounds();
    gOverlayWindow.hidden = NO;
    gOverlayWindow.windowLevel = UIWindowLevelAlert + 1000.0;
    if (gButtonWindow) {
        gButtonWindow.hidden = YES;
        gButtonWindow.windowLevel = UIWindowLevelAlert + 1001.0;
    }
    gPreviousKeyWindow = RAACHEATKeyWindowForScene(nil);
    if (RAACHEATIsRxaaWindow(gPreviousKeyWindow)) {
        gPreviousKeyWindow = nil;
    }
    if (!gPreviousKeyWindow) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (!RAACHEATIsRxaaWindow(window) && !window.hidden) {
                gPreviousKeyWindow = window;
                break;
            }
        }
    }
    [gOverlayWindow makeKeyAndVisible];

    RXAAMenuViewController *menu = [[RXAAMenuViewController alloc] init];
    RXAANavigationController *nav = [[RXAANavigationController alloc] initWithRootViewController:menu];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    nav.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    nav.modalPresentationCapturesStatusBarAppearance = YES;
    nav.view.backgroundColor = RXAABackground();
    gMenuNav = nav;
    [root presentViewController:nav animated:YES completion:^{
        if (root.presentedViewController != nav) {
            NSLog(@"[Rxaa] presentation did not complete");
            gMenuNav = nil;
            RAACHEATRestorePreviousKeyWindow();
        }
    }];
}

@implementation RAACHEATRootController

- (void)loadView {
    self.view = [[RAACHEATPassThroughView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        (void)context;
        RAACHEATRefreshOverlayBounds();
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        (void)context;
        RAACHEATRefreshOverlayBounds();
    }];
}

- (void)raacheatOpen {
    RAACHEATOpenPanel();
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

@end

@implementation RAACHEATButtonController

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                         kRXAAFloatButtonSize,
                                                         kRXAAFloatButtonSize)];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.clipsToBounds = NO;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (gFloatButton) {
        gFloatButton.frame = self.view.bounds;
    }
}

- (void)raacheatOpen {
    RAACHEATOpenPanel();
}

- (void)raacheatPan:(UIPanGestureRecognizer *)pan {
    if (!gButtonWindow) {
        return;
    }

    UIView *reference = gOverlayWindow ?: self.view;
    if (pan.state == UIGestureRecognizerStateBegan) {
        gButtonPanStartCenter = gButtonWindow.center;
        gButtonPanStartPoint = [pan locationInView:reference];
        gButtonWindow.hidden = NO;
        [UIView animateWithDuration:0.12
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            gFloatButton.alpha = 0.82;
        } completion:nil];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint point = [pan locationInView:reference];
        CGPoint center = CGPointMake(
            gButtonPanStartCenter.x + (point.x - gButtonPanStartPoint.x),
            gButtonPanStartCenter.y + (point.y - gButtonPanStartPoint.y));
        gButtonWindow.center = RAACHEATClampFloatButtonCenter(center);
    } else if (pan.state == UIGestureRecognizerStateEnded ||
               pan.state == UIGestureRecognizerStateCancelled ||
               pan.state == UIGestureRecognizerStateFailed) {
        gButtonWindow.center = RAACHEATClampFloatButtonCenter(gButtonWindow.center);
        RAACHEATSaveFloatButtonPosition();
        [UIView animateWithDuration:0.15
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            gFloatButton.alpha = 1.0;
        } completion:nil];
    }
}

@end

static NSArray<NSString *> *RXAAFeatureTitles(void) {
    return @[@"AimLock", @"ESP", @"Radar"];
}

static NSArray<NSString *> *RXAAFeatureKeys(void) {
    return @[@"rxaa.aimlock", @"rxaa.esp", @"rxaa.radar"];
}

@implementation RXAAMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Rxaa";
    self.view.backgroundColor = RXAABackground();
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Close"
                style:UIBarButtonItemStyleDone
                target:self
                action:@selector(closeMenu)];

    self.sidebarTableView = [[UITableView alloc] initWithFrame:CGRectZero
                                                          style:UITableViewStylePlain];
    self.sidebarTableView.dataSource = self;
    self.sidebarTableView.delegate = self;
    self.sidebarTableView.backgroundColor = [UIColor colorWithWhite:0.025 alpha:1.0];
    self.sidebarTableView.separatorColor = [UIColor colorWithWhite:0.10 alpha:1.0];
    self.sidebarTableView.tableFooterView = [[UIView alloc] init];
    self.sidebarTableView.rowHeight = 54.0;
    self.sidebarTableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 24.0, 0.0);
    self.sidebarTableView.showsVerticalScrollIndicator = NO;

    self.detailTableView = [[UITableView alloc] initWithFrame:CGRectZero
                                                         style:UITableViewStylePlain];
    self.detailTableView.dataSource = self;
    self.detailTableView.delegate = self;
    self.detailTableView.backgroundColor = RXAABackground();
    self.detailTableView.separatorColor = [UIColor colorWithWhite:0.13 alpha:1.0];
    self.detailTableView.tableFooterView = [[UIView alloc] init];
    self.detailTableView.rowHeight = 64.0;
    self.detailTableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 24.0, 0.0);

    self.dividerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.dividerView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];

    [self.view addSubview:self.sidebarTableView];
    [self.view addSubview:self.dividerView];
    [self.view addSubview:self.detailTableView];

    self.activeCategory = RXAACatalogCategories().firstObject;
    self.detailMode = RXAAMenuDetailModeCatalog;

    [self configureNavigationBar];
}

- (void)configureNavigationBar {
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = RXAABackground();
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName: RXAAGreen()};
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
    }
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = RXAAGreen();
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self configureNavigationBar];
    [self.sidebarTableView reloadData];
    [self.detailTableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self selectActiveSidebarRow];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect bounds = self.view.bounds;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    UIEdgeInsets safe = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safe = self.view.safeAreaInsets;
    }
    CGFloat usableWidth = MAX(0.0, width - safe.left - safe.right);
    CGFloat sidebarWidth = MIN(232.0, MAX(132.0, usableWidth * 0.30));
    CGFloat dividerWidth = 1.0 / MAX(1.0, [UIScreen mainScreen].scale);

    self.sidebarTableView.frame = CGRectMake(safe.left, 0.0, sidebarWidth, height);
    self.dividerView.frame = CGRectMake(safe.left + sidebarWidth, 0.0, dividerWidth, height);
    self.detailTableView.frame = CGRectMake(safe.left + sidebarWidth + dividerWidth, 0.0,
                                            MAX(0.0, usableWidth - sidebarWidth - dividerWidth),
                                            height);
    self.sidebarTableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, safe.bottom + 24.0, 0.0);
    self.detailTableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, safe.bottom + 24.0, 0.0);
    self.sidebarTableView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0, 0.0, safe.bottom, 0.0);
    self.detailTableView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0, 0.0, safe.bottom, 0.0);
}

- (void)selectActiveSidebarRow {
    NSIndexPath *indexPath = nil;
    if (self.detailMode == RXAAMenuDetailModeTools) {
        indexPath = [NSIndexPath indexPathForRow:0 inSection:2];
    } else {
        NSArray<NSDictionary *> *rows = RXAASidebarCatalogRows();
        NSUInteger row = 0;
        for (NSUInteger i = 0; i < rows.count; i++) {
            if ([rows[i][@"key"] isEqualToString:self.activeCategory]) {
                row = i;
                break;
            }
        }
        indexPath = [NSIndexPath indexPathForRow:(NSInteger)row inSection:0];
    }
    [self.sidebarTableView selectRowAtIndexPath:indexPath
                                       animated:NO
                                 scrollPosition:UITableViewScrollPositionNone];
}

- (void)closeMenu {
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
        gMenuNav = nil;
        RAACHEATRestorePreviousKeyWindow();
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || self.navigationController.isBeingDismissed) {
        gMenuNav = nil;
        RAACHEATRestorePreviousKeyWindow();
    }
}

#pragma mark - Table data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView == self.sidebarTableView) {
        return 3;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.sidebarTableView) {
        if (section == 0) {
            return (NSInteger)[RXAASidebarCatalogRows() count];
        }
        return 1;
    }

    if (self.detailMode == RXAAMenuDetailModeTools) {
        return (NSInteger)[RXAAMenuToolRows() count];
    }
    return (NSInteger)[RXAACatalogAllFeaturesForCategory(self.activeCategory) count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (tableView == self.sidebarTableView) {
        if (section == 0) {
            return @"CATALOG";
        } else if (section == 1) {
            return @"ALL DATA";
        }
        return @"TOOLS";
    }

    if (self.detailMode == RXAAMenuDetailModeTools) {
        return @"TOOLS & ACTIONS";
    }
    NSUInteger count = [RXAACatalogAllFeaturesForCategory(self.activeCategory) count];
    return [NSString stringWithFormat:@"%@  (%lu)",
            [RXAACatalogCategoryDisplayName(self.activeCategory) uppercaseString],
            (unsigned long)count];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (tableView == self.sidebarTableView) {
        if (section == 2) {
            return @"UI-only debug build. No game hooks, no process access, no memory writes.";
        }
        return nil;
    }
    if (self.detailMode == RXAAMenuDetailModeTools) {
        return @"Demo actions only. The Python engine writes local config files; it does not inject into or modify a game.";
    }
    return @"Catalog reference rows. Switches save locally and never touch a game process.";
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view
       forSection:(NSInteger)section {
    if (![view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        return;
    }
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    if (tableView == self.sidebarTableView) {
        header.contentView.backgroundColor = [UIColor colorWithWhite:0.025 alpha:1.0];
        header.textLabel.textColor = [UIColor colorWithWhite:0.40 alpha:1.0];
        header.textLabel.font = [UIFont monospacedSystemFontOfSize:9.0
                                                            weight:UIFontWeightBold];
    } else {
        header.contentView.backgroundColor = RXAABackground();
        header.textLabel.textColor = RXAAGreen();
        header.textLabel.font = [UIFont monospacedSystemFontOfSize:10.0
                                                            weight:UIFontWeightBold];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.sidebarTableView) {
        return [self sidebarCellForRowAtIndexPath:indexPath];
    }
    return [self detailCellForRowAtIndexPath:indexPath];
}

- (UITableViewCell *)sidebarCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"RXAASidebarCell";
    UITableViewCell *cell = [self.sidebarTableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor colorWithWhite:0.035 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.72;
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.48 alpha:1.0];
        cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:9.0
                                                               weight:UIFontWeightRegular];
        UIView *selected = [[UIView alloc] init];
        selected.backgroundColor = [UIColor colorWithRed:0.04 green:0.20 blue:0.12 alpha:1.0];
        cell.selectedBackgroundView = selected;
    }

    NSDictionary *entry = nil;
    BOOL isNavigationRow = NO;
    if (indexPath.section == 0) {
        NSArray<NSDictionary *> *rows = RXAASidebarCatalogRows();
        if ((NSUInteger)indexPath.row < rows.count) {
            entry = rows[(NSUInteger)indexPath.row];
        }
    } else if (indexPath.section == 1) {
        entry = @{
            @"title": @"Full Catalog",
            @"subtitle": [NSString stringWithFormat:@"%lu entries",
                          (unsigned long)[RXAACatalogAllFeatures() count]]
        };
        isNavigationRow = YES;
    } else {
        entry = @{
            @"title": @"Tools & Actions",
            @"subtitle": @"Apply, reset, Python, links"
        };
        isNavigationRow = YES;
    }

    cell.textLabel.text = entry[@"title"] ?: @"";
    cell.detailTextLabel.text = entry[@"subtitle"] ?: @"";
    cell.accessoryType = isNavigationRow ? UITableViewCellAccessoryDisclosureIndicator
                                         : UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (UITableViewCell *)detailCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.detailMode == RXAAMenuDetailModeTools) {
        static NSString *toolCellID = @"RXAAToolCell";
        UITableViewCell *cell = [self.detailTableView dequeueReusableCellWithIdentifier:toolCellID];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                          reuseIdentifier:toolCellID];
            cell.backgroundColor = [UIColor colorWithWhite:0.045 alpha:1.0];
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.textLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
            cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.62 alpha:1.0];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:11.0];
        }

        NSArray<NSDictionary *> *rows = RXAAMenuToolRows();
        if ((NSUInteger)indexPath.row >= rows.count) {
            return cell;
        }
        NSDictionary *row = rows[(NSUInteger)indexPath.row];
        NSString *action = row[@"action"];
        cell.textLabel.text = row[@"title"] ?: @"";
        cell.detailTextLabel.text = row[@"subtitle"] ?: @"";
        cell.accessoryView = nil;
        cell.accessoryType = ([action isEqualToString:@"apply-all"] ||
                              [action isEqualToString:@"reset-all"])
                                 ? UITableViewCellAccessoryNone
                                 : UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    static NSString *featureCellID = @"RXAAFeatureCell";
    UITableViewCell *cell = [self.detailTableView dequeueReusableCellWithIdentifier:featureCellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:featureCellID];
        cell.backgroundColor = [UIColor colorWithWhite:0.045 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.7;
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.58 alpha:1.0];
        cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:9.5
                                                               weight:UIFontWeightRegular];
    }

    NSArray<NSDictionary *> *features = RXAACatalogAllFeaturesForCategory(self.activeCategory);
    if ((NSUInteger)indexPath.row >= features.count) {
        return cell;
    }
    NSDictionary *item = features[(NSUInteger)indexPath.row];
    NSString *kind = item[@"kind"] ?: @"entry";
    NSString *va = item[@"va"] ?: @"";
    cell.textLabel.text = item[@"label"] ?: @"(unnamed)";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  |  %@", kind, va];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    if (RXAACatalogFeatureIsActionable(item)) {
        RXAACatalogSwitch *sw = [[RXAACatalogSwitch alloc] init];
        sw.featureKey = RXAACatalogFeatureKey(item);
        sw.onTintColor = RXAAGreen();
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:sw.featureKey];
        sw.accessibilityLabel = item[@"label"];
        [sw addTarget:self
               action:@selector(catalogSwitchChanged:)
     forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (void)catalogSwitchChanged:(UISwitch *)sender {
    if (![sender isKindOfClass:[RXAACatalogSwitch class]]) {
        return;
    }
    RXAACatalogSwitch *sw = (RXAACatalogSwitch *)sender;
    if (!sw.featureKey) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:sw.featureKey];
}

- (NSUInteger)setAllDemoSwitches:(BOOL)on {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in RXAAFeatureKeys()) {
        [defaults setBool:on forKey:key];
    }
    NSUInteger count = 0;
    for (NSDictionary *item in RXAACatalogAllFeatures()) {
        if (RXAACatalogFeatureIsActionable(item)) {
            [defaults setBool:on forKey:RXAACatalogFeatureKey(item)];
            count++;
        }
    }
    [defaults synchronize];
    [self.sidebarTableView reloadData];
    [self.detailTableView reloadData];
    [self selectActiveSidebarRow];
    return count;
}

- (void)showDemoActionAlert:(BOOL)on count:(NSUInteger)count {
    NSString *title = on ? @"Applied (Demo)" : @"Reset (Demo)";
    NSString *message = [NSString stringWithFormat:
        @"%lu local catalog switches were turned %@.\n\nThis only writes NSUserDefaults. No game process is contacted.",
        (unsigned long)count, on ? @"ON" : @"OFF"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFeatureDetails:(NSDictionary *)item {
    NSMutableString *message = [NSMutableString string];
    NSString *category = item[@"category"] ?: @"unknown";
    NSString *kind = item[@"kind"] ?: @"entry";
    NSString *va = item[@"va"] ?: @"n/a";
    NSString *firstXref = item[@"first_xref"] ?: @"n/a";
    [message appendFormat:@"Category: %@\nKind: %@\nString VA: %@\nFirst xref: %@",
                          category, kind, va, firstXref];
    NSDictionary *meta = item[@"meta"];
    if ([meta isKindOfClass:[NSDictionary class]] && meta.count > 0) {
        [message appendString:@"\n\nMetadata:"];
        for (NSString *key in [meta.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [message appendFormat:@"\n%@: %@", key, meta[key]];
        }
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:item[@"label"] ?: @"Catalog Entry"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showPythonEngineInfo {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rxa Python Engine"
        message:@"mod_menu.py is bundled in the tweak's Application Support directory.\n\nTo run on iOS:\n1. Open Terminal (NewTerm or SSH)\n2. Type 'rxa-menu'\n   (or python3 mod_menu.py --cli)\n\nIt provides the interactive CLI, preset loading, and local config generation. It does not inject into a game."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAbout {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"About Rxaa"
        message:@"Rxaa 1.3.1 UI debug build\n\nTwo-pane catalog browser for libRAACHEAT.so and ROS.deb reference data. The ros.dylib in the extracted package is not loaded, hooked, or signed into any game process.\n\nUI-only: no aimbot, ESP, memory read/write, or anti-cheat bypass."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showRepairOverlayDiagnostics {
    RAACHEATAttachWindowToScene();
    RAACHEATEnsureOverlayVisible();

    NSString *sceneDesc = @"none";
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = gOverlayWindow.windowScene;
        if (scene) {
            sceneDesc = [NSString stringWithFormat:@"scene=%p active=%@ bounds=%@",
                         scene, @(scene.activationState == UISceneActivationStateForegroundActive),
                         NSStringFromCGRect(scene.coordinateSpace.bounds)];
        }
    }

    NSString *message = [NSString stringWithFormat:
        @"Overlay repair attempted.\n\n"
        @"Overlay: %@\n"
        @"Button: %@\n"
        @"Menu open: %@\n"
        @"Overlay scene: %@\n"
        @"Using legacy windows: %@\n"
        @"Install attempts: %d",
        gOverlayWindow ? @"installed" : @"nil",
        gButtonWindow ? @"installed" : @"nil",
        gMenuNav ? @"YES" : @"NO",
        sceneDesc,
        gUsingLegacyWindows ? @"YES" : @"NO",
        gInstallAttempts];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Repair / Reattach Overlay"
                                                                    message:message
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                          style:UIAlertActionStyleDefault
                                        handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showGameStatusDiagnostics {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"(unknown)";
    NSUInteger sceneCount = 0, windowCount = 0, nonRxaaWindowCount = 0;
    if (@available(iOS 13.0, *)) {
        sceneCount = [UIApplication sharedApplication].connectedScenes.count;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            windowCount++;
            if (!RAACHEATIsRxaaWindow(window)) {
                nonRxaaWindowCount++;
            }
        }
    } else {
        windowCount = [UIApplication sharedApplication].windows.count;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (!RAACHEATIsRxaaWindow(window)) {
                nonRxaaWindowCount++;
            }
        }
    }

    BOOL rosDylibLoaded = NSClassFromString(@"DLGMem") != nil || NSClassFromString(@"DLGMemUIView") != nil;
    BOOL sclLoaded = NSClassFromString(@"SCLAlertView") != nil;

    NSString *message = [NSString stringWithFormat:
        @"Game Status & Diagnostics\n\n"
        @"Bundle ID: %@\n"
        @"App State: %@\n"
        @"Scenes: %lu\n"
        @"Windows: %lu (game: %lu)\n"
        @"Overlay: %@\n"
        @"Button: %@\n"
        @"Menu open: %@\n"
        @"ros.dylib detected: %@\n"
        @"SCLAlertView loaded: %@\n\n"
        @"Note: Rxaa is UI-only. Switches write NSUserDefaults locally and do not hook the game process. If ros.dylib is loaded, it provides its own memory-scanner menu independently.",
        bundleID,
        @([[UIApplication sharedApplication].applicationState == UIApplicationStateActive]),
        (unsigned long)sceneCount,
        (unsigned long)windowCount,
        (unsigned long)nonRxaaWindowCount,
        gOverlayWindow ? @"YES" : @"NO",
        gButtonWindow ? @"YES" : @"NO",
        gMenuNav ? @"YES" : @"NO",
        rosDylibLoaded ? @"YES (DLGMem/DLGMemUIView)" : @"NO",
        sclLoaded ? @"YES" : @"NO"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Game Status & Diagnostics"
                                                                    message:message
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                          style:UIAlertActionStyleDefault
                                        handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleToolAction:(NSString *)action {
    if ([action isEqualToString:@"apply-all"]) {
        NSUInteger count = [self setAllDemoSwitches:YES];
        [self showDemoActionAlert:YES count:count];
    } else if ([action isEqualToString:@"reset-all"]) {
        NSUInteger count = [self setAllDemoSwitches:NO];
        [self showDemoActionAlert:NO count:count];
    } else if ([action isEqualToString:@"get-code"]) {
        RXAACatalogViewController *catalog = [[RXAACatalogViewController alloc] init];
        [self.navigationController pushViewController:catalog animated:YES];
    } else if ([action isEqualToString:@"all-features"]) {
        RXAACatalogFeatureViewController *features = [[RXAACatalogFeatureViewController alloc] init];
        features.showsAllCategories = YES;
        [self.navigationController pushViewController:features animated:YES];
    } else if ([action isEqualToString:@"python"]) {
        [self showPythonEngineInfo];
    } else if ([action isEqualToString:@"telegram"]) {
        NSURL *url = [NSURL URLWithString:@"https://t.me/kun_amra"];
        if (!url) {
            return;
        }
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
            if (success) {
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"Telegram"
                                     message:@"Could not open https://t.me/kun_amra on this device."
                              preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            });
        }];
    } else if ([action isEqualToString:@"repair-overlay"]) {
        [self showRepairOverlayDiagnostics];
    } else if ([action isEqualToString:@"game-status"]) {
        [self showGameStatusDiagnostics];
    } else if ([action isEqualToString:@"about"]) {
        [self showAbout];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.sidebarTableView) {
        if (indexPath.section == 0) {
            NSArray<NSDictionary *> *rows = RXAASidebarCatalogRows();
            if ((NSUInteger)indexPath.row >= rows.count) {
                return;
            }
            self.activeCategory = rows[(NSUInteger)indexPath.row][@"key"];
            self.detailMode = RXAAMenuDetailModeCatalog;
            [self.detailTableView reloadData];
            [self.detailTableView setContentOffset:CGPointZero animated:NO];
            [self selectActiveSidebarRow];
        } else if (indexPath.section == 1) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            RXAACatalogFeatureViewController *features = [[RXAACatalogFeatureViewController alloc] init];
            features.showsAllCategories = YES;
            [self.navigationController pushViewController:features animated:YES];
            [self selectActiveSidebarRow];
        } else {
            self.detailMode = RXAAMenuDetailModeTools;
            [self.detailTableView reloadData];
            [self.detailTableView setContentOffset:CGPointZero animated:NO];
            [self selectActiveSidebarRow];
        }
        return;
    }

    if (self.detailMode == RXAAMenuDetailModeTools) {
        NSArray<NSDictionary *> *rows = RXAAMenuToolRows();
        if ((NSUInteger)indexPath.row < rows.count) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            [self handleToolAction:rows[(NSUInteger)indexPath.row][@"action"]];
        }
        return;
    }

    NSArray<NSDictionary *> *features = RXAACatalogAllFeaturesForCategory(self.activeCategory);
    if ((NSUInteger)indexPath.row < features.count) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self showFeatureDetails:features[(NSUInteger)indexPath.row]];
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end


@implementation RXAACatalogSwitch
@end

@implementation RXAACatalogFeatureViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSArray<NSString *> *categories = self.showsAllCategories ? RXAACatalogAllCategories()
                                                              : RXAACatalogCategories();
    NSMutableArray<NSString *> *visible = [NSMutableArray array];
    for (NSString *category in categories) {
        if ([[self featuresForCategory:category] count] > 0) {
            [visible addObject:category];
        }
    }
    self.visibleCategories = visible.count > 0 ? [visible copy] : categories;
    self.title = self.showsAllCategories
        ? [NSString stringWithFormat:@"Full Catalog (%lu)",
           (unsigned long)[RXAACatalogAllFeatures() count]]
        : [NSString stringWithFormat:@"All Features (%lu)",
           (unsigned long)[RXAACatalogFeatures() count]];
    self.tableView.backgroundColor = RXAABackground();
    self.tableView.separatorColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    self.tableView.tableFooterView = [[UIView alloc] init];
    self.tableView.rowHeight = 60.0;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSArray<NSString *> *)catalogCategories {
    if (self.visibleCategories.count > 0) {
        return self.visibleCategories;
    }
    return self.showsAllCategories ? RXAACatalogAllCategories() : RXAACatalogCategories();
}

- (NSArray<NSDictionary *> *)featuresForCategory:(NSString *)category {
    return self.showsAllCategories ? RXAACatalogAllFeaturesForCategory(category)
                                   : RXAACatalogFeaturesForCategory(category);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)[[self catalogCategories] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray<NSString *> *categories = [self catalogCategories];
    if (section < 0 || section >= (NSInteger)categories.count) {
        return 0;
    }
    return (NSInteger)[[self featuresForCategory:categories[(NSUInteger)section]] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray<NSString *> *categories = [self catalogCategories];
    if (section < 0 || section >= (NSInteger)categories.count) {
        return nil;
    }
    return [RXAACatalogCategoryDisplayName(categories[(NSUInteger)section]) uppercaseString];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"UI-only demo entries. Switches save locally; no game hooks or memory access.";
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view
       forSection:(NSInteger)section {
    if (![view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        return;
    }
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.contentView.backgroundColor = RXAABackground();
    header.textLabel.textColor = RXAAGreen();
    header.textLabel.font = [UIFont monospacedSystemFontOfSize:10.0
                                                        weight:UIFontWeightBold];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"RXAACatalogFeatureCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor colorWithRed:0.07 green:0.10 blue:0.14 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.62 alpha:1.0];
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.72;
    }

    NSArray<NSString *> *categories = [self catalogCategories];
    if (indexPath.section < 0 || indexPath.section >= (NSInteger)categories.count) {
        return cell;
    }
    NSArray<NSDictionary *> *features = [self featuresForCategory:categories[(NSUInteger)indexPath.section]];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)features.count) {
        return cell;
    }
    NSDictionary *item = features[(NSUInteger)indexPath.row];

    NSString *label = item[@"label"];
    NSString *category = item[@"category"];
    NSString *kind = item[@"kind"];
    NSString *va = item[@"va"];
    cell.textLabel.text = label ? label : @"(unnamed)";
    category = category ? category : @"feature";
    kind = kind ? kind : @"entry";
    va = va ? va : @"";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@ - %@", category, kind, va];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (RXAACatalogFeatureIsActionable(item)) {
        RXAACatalogSwitch *sw = [[RXAACatalogSwitch alloc] init];
        sw.featureKey = RXAACatalogFeatureKey(item);
        sw.onTintColor = RXAAGreen();
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:sw.featureKey];
        sw.accessibilityLabel = item[@"label"];
        [sw addTarget:self action:@selector(catalogSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@ - catalog entry", category, kind];
    }
    return cell;
}

- (void)catalogSwitchChanged:(UISwitch *)sender {
    if (![sender isKindOfClass:[RXAACatalogSwitch class]]) {
        return;
    }
    RXAACatalogSwitch *sw = (RXAACatalogSwitch *)sender;
    if (!sw.featureKey) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:sw.featureKey];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end

@implementation RXAACatalogViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Offline Catalog";
    self.view.backgroundColor = [UIColor blackColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Close"
                style:UIBarButtonItemStyleDone
               target:self
               action:@selector(closeMenu)];

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor blackColor];
    self.webView.scrollView.backgroundColor = [UIColor blackColor];
    self.webView.navigationDelegate = self;
    [self.view addSubview:self.webView];

    self.errorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.errorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
    self.errorLabel.font = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightRegular];
    self.errorLabel.hidden = YES;
    [self.view addSubview:self.errorLabel];

    NSString *path = RAACHEATCatalogPath();
    if (!path) {
        [self showCatalogError:@"Offline catalog not found.\n\nReinstall the Rxaa package and verify that one of these files exists:\n\n/var/jb/Library/Application Support/RAACHEATMenuDebug/index.html\n/Library/Application Support/RAACHEATMenuDebug/index.html"];
        return;
    }

    NSURL *url = [NSURL fileURLWithPath:path];
    if (!url) {
        [self showCatalogError:@"Offline catalog path is invalid.\n\nReinstall the Rxaa package."];
        return;
    }
    NSLog(@"[Rxaa] loading offline catalog: %@", path);
    [self.webView loadFileURL:url allowingReadAccessToURL:[url URLByDeletingLastPathComponent]];
}

- (void)showCatalogError:(NSString *)message {
    NSLog(@"[Rxaa] catalog error: %@",
          [message stringByReplacingOccurrencesOfString:@"\n" withString:@" "]);
    self.webView.hidden = YES;
    self.errorLabel.text = message;
    self.errorLabel.hidden = NO;
    [self.view bringSubviewToFront:self.errorLabel];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.webView.frame = self.view.bounds;
    UIEdgeInsets safe = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safe = self.view.safeAreaInsets;
    }
    self.errorLabel.frame = UIEdgeInsetsInsetRect(self.view.bounds,
        UIEdgeInsetsMake(safe.top + 24.0, safe.left + 24.0,
                         safe.bottom + 24.0, safe.right + 24.0));
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    (void)webView;
    (void)navigation;
    self.errorLabel.hidden = YES;
    self.webView.hidden = NO;
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
    (void)webView;
    (void)navigation;
    [self showCatalogError:[NSString stringWithFormat:
        @"Could not load the offline catalog.\n\n%@\n\nReinstall the Rxaa package if this file is missing:\nindex.html", error.localizedDescription]];
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation
            withError:(NSError *)error {
    (void)webView;
    (void)navigation;
    [self showCatalogError:[NSString stringWithFormat:
        @"Could not load the offline catalog.\n\n%@", error.localizedDescription]];
}

- (void)closeMenu {
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
        gMenuNav = nil;
        RAACHEATRestorePreviousKeyWindow();
    }];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end

static UIWindowScene *RAACHEATActiveWindowScene(void) {
    if (@available(iOS 13.0, *)) {
        UIApplication *app = [UIApplication sharedApplication];

        // Prefer the scene that owns the game's key window. This matters when a
        // game swaps scenes after a match starts and the first active scene is
        // not the one currently rendering the game.
        UIWindow *keyWindow = RAACHEATKeyWindowForScene(nil);
        if (keyWindow.windowScene) {
            return keyWindow.windowScene;
        }

        UIWindowScene *fallback = nil;
        BOOL fallbackVisible = NO;
        CGFloat bestArea = 0.0;
        for (UIWindow *window in app.windows) {
            if (RAACHEATIsRxaaWindow(window) || !window.windowScene) {
                continue;
            }
            UIWindowScene *windowScene = window.windowScene;
            if (windowScene.activationState == UISceneActivationStateUnattached) {
                continue;
            }
            CGRect bounds = windowScene.coordinateSpace.bounds;
            CGFloat area = CGRectGetWidth(bounds) * CGRectGetHeight(bounds);
            BOOL visible = !window.hidden;
            if (!fallback ||
                (visible && !fallbackVisible) ||
                (visible == fallbackVisible && area > bestArea)) {
                fallback = windowScene;
                fallbackVisible = visible;
                bestArea = area;
            }
        }
        if (fallback) {
            return fallback;
        }

        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                return windowScene;
            }
            if (!fallback && windowScene.activationState != UISceneActivationStateUnattached) {
                fallback = windowScene;
            }
        }
        return fallback;
    }
    return nil;
}

static UIWindow *RAACHEATHostWindow(UIWindowScene *scene) {
    UIApplication *app = [UIApplication sharedApplication];
    UIWindow *keyWindow = RAACHEATKeyWindowForScene(scene);
    if (keyWindow && keyWindow != gOverlayWindow && keyWindow != gButtonWindow) {
        return keyWindow;
    }
    if (scene) {
        UIWindow *fallback = nil;
        for (UIWindow *window in scene.windows) {
            if (window == gOverlayWindow || window == gButtonWindow) {
                continue;
            }
            if (!window.hidden) {
                return window;
            }
            if (!fallback) {
                fallback = window;
            }
        }
        if (fallback) {
            return fallback;
        }
    }
    for (UIWindow *window in app.windows) {
        if (window != gOverlayWindow && window != gButtonWindow) {
            return window;
        }
    }
    return nil;
}

static void RAACHEATInstallOpenGesture(RAACHEATRootController *root, UIWindowScene *scene) {
    UIWindow *host = RAACHEATHostWindow(scene);
    if (!host || !root) {
        return;
    }
    if (gOpenGesture && gGestureWindow == host &&
        [host.gestureRecognizers containsObject:gOpenGesture]) {
        return;
    }
    if (gOpenGesture && gGestureWindow) {
        [gGestureWindow removeGestureRecognizer:gOpenGesture];
    }
    gOpenGesture = [[UITapGestureRecognizer alloc] initWithTarget:root action:@selector(raacheatOpen)];
    gOpenGesture.numberOfTouchesRequired = 4;
    gOpenGesture.numberOfTapsRequired = 3;
    gOpenGesture.cancelsTouchesInView = NO;
    gOpenGesture.delaysTouchesBegan = NO;
    gOpenGesture.delegate = root;
    [host addGestureRecognizer:gOpenGesture];
    gGestureWindow = host;
    NSLog(@"[Rxaa] fallback gesture installed on %@", host);
}

static void RAACHEATAttachWindowToScene(void) {
    if (!gOverlayWindow) {
        return;
    }

    UIWindowScene *scene = nil;
    if (@available(iOS 13.0, *)) {
        scene = RAACHEATActiveWindowScene();
        if (scene) {
            gUsingLegacyWindows = NO;
            if (gOverlayWindow.windowScene != scene) {
                gOverlayWindow.windowScene = scene;
            }
            if (gButtonWindow && gButtonWindow.windowScene != scene) {
                gButtonWindow.windowScene = scene;
            }
            CGRect bounds = scene.coordinateSpace.bounds;
            if (!CGRectIsEmpty(bounds)) {
                gOverlayWindow.frame = bounds;
            }
        }
    }

    CGRect bounds = gOverlayWindow.bounds;
    if (CGRectIsEmpty(bounds)) {
        bounds = RAACHEATScreenBounds();
    }
    UIViewController *root = gOverlayWindow.rootViewController;
    if (root && !CGRectIsEmpty(bounds)) {
        root.view.frame = bounds;
    }
    RAACHEATInstallOpenGesture((RAACHEATRootController *)root, scene);

    gOverlayWindow.windowLevel = UIWindowLevelAlert + 1000.0;
    if (gButtonWindow) {
        gButtonWindow.windowLevel = UIWindowLevelAlert + 1001.0;
        if (gMenuNav) {
            gOverlayWindow.hidden = NO;
            gButtonWindow.hidden = YES;
        } else {
            gOverlayWindow.hidden = YES;
            gButtonWindow.hidden = NO;
            RAACHEATRestoreFloatButtonPosition();
        }
    }
}

static void RAACHEATEnsureOverlayVisible(void) {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }
    if (!gOverlayWindow) {
        RAACHEATTryInstall();
        return;
    }

    UIViewController *root = gOverlayWindow.rootViewController;
    if (!gMenuDismissing && root.presentedViewController) {
        if (!gMenuNav || root.presentedViewController != gMenuNav) {
            NSLog(@"[Rxaa] clearing stale presentation: %@", root.presentedViewController);
            gMenuNav = nil;
            [root dismissViewControllerAnimated:NO completion:nil];
        }
    }

    RAACHEATAttachWindowToScene();

    if (gMenuNav) {
        gOverlayWindow.hidden = NO;
        if (gButtonWindow) {
            gButtonWindow.hidden = YES;
        }
        [gOverlayWindow makeKeyAndVisible];
    } else {
        gOverlayWindow.hidden = YES;
        if (gButtonWindow) {
            gButtonWindow.hidden = NO;
        }
    }
}

static void RAACHEATInstallOverlay(void) {
    if (gOverlayWindow) {
        return;
    }

    UIApplication *app = [UIApplication sharedApplication];
    if (!app) {
        return;
    }

    UIWindowScene *scene = nil;
    if (@available(iOS 13.0, *)) {
        scene = RAACHEATActiveWindowScene();
        if (scene) {
            gUsingLegacyWindows = NO;
            gOverlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        } else if (app.windows.count > 0) {
            // Older/legacy apps can have windows without adopting UIScene.
            NSLog(@"[Rxaa] no UIWindowScene; using legacy window fallback");
            gUsingLegacyWindows = YES;
            gOverlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        } else {
            NSLog(@"[Rxaa] waiting for active UIWindowScene");
            return;
        }
    } else {
        gUsingLegacyWindows = YES;
        gOverlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }

    CGRect bounds = scene ? scene.coordinateSpace.bounds : [UIScreen mainScreen].bounds;
    if (CGRectIsEmpty(bounds)) {
        bounds = [UIScreen mainScreen].bounds;
    }

    gOverlayWindow.frame = bounds;
    gOverlayWindow.windowLevel = UIWindowLevelAlert + 1000.0;
    gOverlayWindow.backgroundColor = [UIColor clearColor];
    gOverlayWindow.rootViewController = [[RAACHEATRootController alloc] init];
    gOverlayWindow.hidden = YES;

    RAACHEATRootController *root = (RAACHEATRootController *)gOverlayWindow.rootViewController;
    root.view.frame = bounds;

    gFloatButton = [UIButton buttonWithType:UIButtonTypeSystem];
    gFloatButton.frame = CGRectMake(0.0, 0.0,
                                    kRXAAFloatButtonSize, kRXAAFloatButtonSize);
    gFloatButton.autoresizingMask = UIViewAutoresizingNone;
    gFloatButton.backgroundColor = [UIColor colorWithRed:0.06 green:0.13 blue:0.10 alpha:0.94];
    gFloatButton.layer.cornerRadius = kRXAAFloatButtonSize * 0.5;
    gFloatButton.layer.borderWidth = 1.0;
    gFloatButton.layer.borderColor = [UIColor colorWithRed:0.31 green:0.94 blue:0.65 alpha:0.85].CGColor;
    gFloatButton.clipsToBounds = YES;
    gFloatButton.accessibilityLabel = @"Rxaa";

    NSString *iconPath = RAACHEATResourcePath(@"menu_icon.png");
    if (!iconPath) {
        iconPath = RAACHEATResourcePath(@"menu_image.jpg");
    }
    UIImage *icon = iconPath ? [UIImage imageWithContentsOfFile:iconPath] : nil;
    if (icon) {
        [gFloatButton setBackgroundImage:icon forState:UIControlStateNormal];
    } else {
        [gFloatButton setTitle:@"R" forState:UIControlStateNormal];
        [gFloatButton setTitleColor:RXAAGreen() forState:UIControlStateNormal];
        gFloatButton.titleLabel.font = [UIFont monospacedSystemFontOfSize:22 weight:UIFontWeightBold];
    }

    RAACHEATButtonController *buttonRoot = [[RAACHEATButtonController alloc] init];
    if (@available(iOS 13.0, *)) {
        if (scene) {
            gButtonWindow = [[UIWindow alloc] initWithWindowScene:scene];
        }
    }
    if (!gButtonWindow) {
        gButtonWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                   kRXAAFloatButtonSize,
                                                                   kRXAAFloatButtonSize)];
    }
    gButtonWindow.frame = CGRectMake(0.0, 0.0,
                                     kRXAAFloatButtonSize, kRXAAFloatButtonSize);
    gButtonWindow.windowLevel = UIWindowLevelAlert + 1001.0;
    gButtonWindow.backgroundColor = [UIColor clearColor];
    gButtonWindow.rootViewController = buttonRoot;
    gButtonWindow.hidden = NO;
    gFloatButton.frame = buttonRoot.view.bounds;
    [buttonRoot.view addSubview:gFloatButton];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:buttonRoot action:@selector(raacheatPan:)];
    pan.cancelsTouchesInView = YES;
    pan.maximumNumberOfTouches = 1;
    [gFloatButton addGestureRecognizer:pan];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:buttonRoot action:@selector(raacheatOpen)];
    tap.numberOfTapsRequired = 1;
    tap.cancelsTouchesInView = NO;
    [gFloatButton addGestureRecognizer:tap];

    RAACHEATRestoreFloatButtonPosition();
    RAACHEATInstallOpenGesture(root, scene);
    NSLog(@"[Rxaa] overlay installed scene=%@ bounds=%@", scene, NSStringFromCGRect(bounds));
}

static void RAACHEATScheduleInstallRetry(void) {
    if (gInstallRetryScheduled) {
        return;
    }
    gInstallRetryScheduled = YES;

    NSTimeInterval delay = 1.0;
    if (gInstallAttempts > 10) {
        delay = 2.0;
    }
    if (gInstallAttempts > 30) {
        delay = 5.0;
    }
    if (gInstallAttempts > 60) {
        delay = 10.0;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gInstallRetryScheduled = NO;
        RAACHEATTryInstall();
    });
}

static void RAACHEATTryInstall(void) {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        RAACHEATScheduleInstallRetry();
        return;
    }

    if (gOverlayWindow) {
        RAACHEATAttachWindowToScene();
        if (@available(iOS 13.0, *)) {
            BOOL needsScene = !gOverlayWindow.windowScene && !gUsingLegacyWindows;
            BOOL needsButton = gButtonWindow == nil;
            if (needsScene || needsButton) {
                gInstallAttempts++;
                RAACHEATScheduleInstallRetry();
            }
        }
        return;
    }

    gInstallAttempts++;
    RAACHEATInstallOverlay();
    if (!gOverlayWindow) {
        RAACHEATScheduleInstallRetry();
        return;
    }

    gInstallAttempts = 0;
    RAACHEATEnsureOverlayVisible();
}

static void RAACHEATObserveLifecycle(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        id activationToken = [center addObserverForName:UIApplicationDidBecomeActiveNotification
                                                object:nil
                                                 queue:[NSOperationQueue mainQueue]
                                            usingBlock:^(NSNotification *note) {
            (void)note;
            gInstallAttempts = 0;
            gMenuDismissing = NO;
            if (gOverlayWindow) {
                RAACHEATEnsureOverlayVisible();
            } else {
                RAACHEATTryInstall();
            }
        }];
        (void)activationToken;

        id resignationToken = [center addObserverForName:UIApplicationWillResignActiveNotification
                                                  object:nil
                                                   queue:[NSOperationQueue mainQueue]
                                              usingBlock:^(NSNotification *note) {
            (void)note;
            RAACHEATDismissMenuForResignation();
        }];
        (void)resignationToken;

        if (@available(iOS 13.0, *)) {
            id sceneToken = [center addObserverForName:UISceneDidActivateNotification
                                                object:nil
                                                 queue:[NSOperationQueue mainQueue]
                                            usingBlock:^(NSNotification *note) {
                (void)note;
                gInstallAttempts = 0;
                if (gOverlayWindow) {
                    RAACHEATEnsureOverlayVisible();
                } else {
                    RAACHEATTryInstall();
                }
            }];
            (void)sceneToken;
        }

        id keyToken = [center addObserverForName:UIWindowDidBecomeKeyNotification
                                          object:nil
                                           queue:[NSOperationQueue mainQueue]
                                      usingBlock:^(NSNotification *note) {
            if (!gOverlayWindow) {
                RAACHEATTryInstall();
                return;
            }
            if ([note.object isKindOfClass:[UIWindow class]] &&
                RAACHEATIsRxaaWindow((UIWindow *)note.object)) {
                return;
            }
            if (gMenuNav && [note.object isKindOfClass:[UIWindow class]]) {
                // The game created or promoted a new window after the menu was
                // opened. Remember it so closing the menu returns to the right one.
                gPreviousKeyWindow = (UIWindow *)note.object;
            }
            RAACHEATEnsureOverlayVisible();
        }];
        (void)keyToken;

        id visibleToken = [center addObserverForName:UIWindowDidBecomeVisibleNotification
                                              object:nil
                                               queue:[NSOperationQueue mainQueue]
                                          usingBlock:^(NSNotification *note) {
            if (!gOverlayWindow) {
                RAACHEATTryInstall();
                return;
            }
            if ([note.object isKindOfClass:[UIWindow class]] &&
                RAACHEATIsRxaaWindow((UIWindow *)note.object)) {
                return;
            }
            RAACHEATEnsureOverlayVisible();
        }];
        (void)visibleToken;

        id orientationToken = [center addObserverForName:UIDeviceOrientationDidChangeNotification
                                                  object:nil
                                                   queue:[NSOperationQueue mainQueue]
                                              usingBlock:^(NSNotification *note) {
            (void)note;
            if (gOverlayWindow) {
                RAACHEATEnsureOverlayVisible();
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (gOverlayWindow) {
                        RAACHEATEnsureOverlayVisible();
                    }
                });
            } else {
                RAACHEATTryInstall();
            }
        }];
        (void)orientationToken;
    });
}

%ctor {
    @autoreleasepool {
        RAACHEATObserveLifecycle();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            RAACHEATTryInstall();
        });
    }
}
